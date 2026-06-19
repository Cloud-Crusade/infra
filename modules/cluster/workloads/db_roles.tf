locals {
  # 서비스 → 물리 DB(writer/reader 고정 DNS) + 전용 DB 롤. 물리 DB 공유, 테이블 소유권은 롤별 격리
  svc_db = {
    auth        = { writer = "rds-core-writer", reader = "rds-core-reader", role = "auth_svc" }
    event       = { writer = "rds-core-writer", reader = "rds-core-reader", role = "event_svc" }
    reservation = { writer = "rds-reservation-writer", reader = "rds-reservation-reader", role = "reservation_svc" }
    payment     = { writer = "rds-reservation-writer", reader = "rds-reservation-reader", role = "payment_svc" }
  }

  # 서비스명 → 전체 이미지 레퍼런스. 리포지토리(<namespace>/<svc>)는 terraform 밖에서 선행 생성,
  # 이후 롤아웃은 cc/app CD(kubectl set image) 소유 → workload 의 image 는 ignore_changes
  ticketing_images = { for k in keys(local.svc_db) : k => "${var.ecr_registry}/${var.ecr_namespace}/${k}:${var.ticketing_image_tag}" }
}

# 롤 비밀번호는 data 레이어에서 생성·프록시 auth 에 등록됨 → 여기선 주입받아 사용(var.svc_role_passwords)

# 서비스별 DB 크리덴셜(자기 롤). 호스트는 고정 DNS(ExternalName) → 컷오버 시 URL 불변
resource "kubernetes_secret_v1" "ticketing_db" {
  for_each = local.svc_db
  metadata {
    name      = "ticketing-${each.key}-db"
    namespace = local.ticketing_namespace
  }
  data = {
    DB_WRITER_URL = "postgresql+asyncpg://${each.value.role}:${var.svc_role_passwords[each.value.role]}@${each.value.writer}:5432/${var.db_name}"
    DB_READER_URL = "postgresql+asyncpg://${each.value.role}:${var.svc_role_passwords[each.value.role]}@${each.value.reader}:5432/${var.db_name}"
  }
  depends_on = [kubernetes_namespace_v1.ticketing]
}

# ---- DB 롤 부트스트랩 (master 크리덴셜로 롤 생성 + GRANT) ----
resource "kubernetes_secret_v1" "db_bootstrap" {
  metadata {
    name      = "ticketing-db-bootstrap"
    namespace = local.ticketing_namespace
  }
  data = {
    MASTER_USER     = var.db_username
    MASTER_PASSWORD = var.db_password
    DB_NAME         = var.db_name
    AUTH_PW         = var.svc_role_passwords["auth_svc"]
    EVENT_PW        = var.svc_role_passwords["event_svc"]
    RESERVATION_PW  = var.svc_role_passwords["reservation_svc"]
    PAYMENT_PW      = var.svc_role_passwords["payment_svc"]
  }
  depends_on = [kubernetes_namespace_v1.ticketing]
}

resource "kubernetes_config_map_v1" "db_bootstrap_sql" {
  metadata {
    name      = "ticketing-db-bootstrap-sql"
    namespace = local.ticketing_namespace
  }
  data = {
    "role.sql" = <<-SQL
      SELECT format('CREATE ROLE %I LOGIN', :'role')
      WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'role')\gexec
      ALTER ROLE :"role" WITH PASSWORD :'pw';
      GRANT CONNECT ON DATABASE :"db" TO :"role";
      GRANT USAGE, CREATE ON SCHEMA public TO :"role";
      -- 테이블 소유자가 master 라 서비스 롤에 명시 GRANT 필요. 기존 테이블 + 시퀀스
      GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO :"role";
      GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO :"role";
      -- 이후 master 가 만드는 테이블/시퀀스도 자동 부여(마이그레이션이 master 로 실행되는 경우)
      ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO :"role";
      ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO :"role";
    SQL
    "run.sh"   = <<-SH
      #!/bin/sh
      set -e
      # cold build: 프록시→DB 타겟이 healthy 될 때까지 대기(타이밍 레이스로 인한 backoff 소진 방지).
      # Multi-AZ RDS 는 프로비저닝이 ~15-20분으로 길고 bootstrap 이 병렬 실행되므로 대기 예산을 넉넉히(최대 20분).
      wait_db() {
        i=0
        until PGPASSWORD="$MASTER_PASSWORD" psql "host=$1 port=5432 dbname=$DB_NAME user=$MASTER_USER sslmode=require connect_timeout=5" -tAc 'select 1' >/dev/null 2>&1; do
          i=$((i + 1))
          [ "$i" -ge 120 ] && { echo "DB 연결 대기 타임아웃: $1"; exit 1; }
          echo "DB 미준비($1) — 10s 후 재시도 ($i/120)"; sleep 10
        done
      }
      wait_db rds-core-writer
      wait_db rds-reservation-writer

      bootstrap() {
        PGPASSWORD="$MASTER_PASSWORD" psql "host=$1 port=5432 dbname=$DB_NAME user=$MASTER_USER sslmode=require" \
          -v ON_ERROR_STOP=1 -v role="$2" -v pw="$3" -v db="$DB_NAME" -f /sql/role.sql
      }
      bootstrap rds-core-writer        auth_svc        "$AUTH_PW"
      bootstrap rds-core-writer        event_svc       "$EVENT_PW"
      bootstrap rds-reservation-writer reservation_svc "$RESERVATION_PW"
      bootstrap rds-reservation-writer payment_svc     "$PAYMENT_PW"
    SH
  }
  depends_on = [kubernetes_namespace_v1.ticketing]
}

resource "kubernetes_job_v1" "db_bootstrap" {
  metadata {
    name      = "ticketing-db-bootstrap"
    namespace = local.ticketing_namespace
  }

  spec {
    backoff_limit = 3
    template {
      metadata {
        labels = { app = "ticketing-db-bootstrap" }
      }
      spec {
        restart_policy = "OnFailure"

        # app 노드그룹 taint 수용
        toleration {
          key      = "dedicated"
          value    = "app"
          operator = "Equal"
          effect   = "NoSchedule"
        }
        node_selector = { role = "app" }

        container {
          name    = "bootstrap"
          image   = "postgres:16-alpine"
          command = ["/bin/sh", "/script/run.sh"]

          env_from {
            secret_ref { name = kubernetes_secret_v1.db_bootstrap.metadata[0].name }
          }
          volume_mount {
            name       = "sql"
            mount_path = "/sql"
          }
          volume_mount {
            name       = "script"
            mount_path = "/script"
          }
        }

        volume {
          name = "sql"
          config_map {
            name = kubernetes_config_map_v1.db_bootstrap_sql.metadata[0].name
            items {
              key  = "role.sql"
              path = "role.sql"
            }
          }
        }
        volume {
          name = "script"
          config_map {
            name = kubernetes_config_map_v1.db_bootstrap_sql.metadata[0].name
            items {
              key  = "run.sh"
              path = "run.sh"
            }
          }
        }
      }
    }
  }

  wait_for_completion = true
  # Multi-AZ RDS 병렬 프로비저닝(~15-20분) 대기 수용 — wait_db 예산(최대 20분)보다 넉넉히
  timeouts {
    create = "25m"
  }

  # 완료된 Job 은 자동 재실행되지 않음 — 롤 비밀번호 회전·롤 추가·스크립트 변경 시
  # data(SQL/run.sh·시크릿)가 바뀌면 Job 재생성해 재실행(role.sql 은 멱등). in-place 변경 감지를
  # 위해 .data 속성을 참조(전체 리소스 참조는 replace 시에만 발화).
  lifecycle {
    replace_triggered_by = [
      kubernetes_config_map_v1.db_bootstrap_sql.data,
      kubernetes_secret_v1.db_bootstrap.data,
    ]
  }

  depends_on = [
    kubernetes_service_v1.rds_core_writer,
    kubernetes_service_v1.rds_reservation_writer,
  ]
}
