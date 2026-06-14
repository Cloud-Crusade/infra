locals {
  # 서비스 → 물리 DB(writer/reader 고정 DNS) + 전용 DB 롤. 물리 DB 공유, 테이블 소유권은 롤별 격리
  svc_db = {
    auth        = { writer = "rds-core-writer", reader = "rds-core-reader", role = "auth_svc" }
    event       = { writer = "rds-core-writer", reader = "rds-core-reader", role = "event_svc" }
    reservation = { writer = "rds-reservation-writer", reader = "rds-reservation-reader", role = "reservation_svc" }
    payment     = { writer = "rds-reservation-writer", reader = "rds-reservation-reader", role = "payment_svc" }
  }

  # 서비스명 → 전체 이미지 레퍼런스. 리포지토리(ticketing-<svc>)는 terraform 밖에서 선행 생성,
  # 이후 롤아웃은 cc/app CD(kubectl set image) 소유 → workload 의 image 는 ignore_changes
  ticketing_images = { for k in keys(local.svc_db) : k => "${var.ecr_registry}/ticketing-${k}:${var.ticketing_image_tag}" }
}

# asyncpg URL 파싱 안정성 위해 special=false
resource "random_password" "db_role" {
  for_each = local.svc_db
  length   = 32
  special  = false
}

# 서비스별 DB 크리덴셜(자기 롤). 호스트는 고정 DNS(ExternalName) → 컷오버 시 URL 불변
resource "kubernetes_secret_v1" "ticketing_db" {
  for_each = local.svc_db
  metadata {
    name      = "ticketing-${each.key}-db"
    namespace = local.ticketing_namespace
  }
  data = {
    DB_WRITER_URL = "postgresql+asyncpg://${each.value.role}:${random_password.db_role[each.key].result}@${each.value.writer}:5432/${var.db_name}"
    DB_READER_URL = "postgresql+asyncpg://${each.value.role}:${random_password.db_role[each.key].result}@${each.value.reader}:5432/${var.db_name}"
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
    AUTH_PW         = random_password.db_role["auth"].result
    EVENT_PW        = random_password.db_role["event"].result
    RESERVATION_PW  = random_password.db_role["reservation"].result
    PAYMENT_PW      = random_password.db_role["payment"].result
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
    SQL
    "run.sh"   = <<-SH
      #!/bin/sh
      set -e
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
  timeouts {
    create = "5m"
  }

  depends_on = [
    kubernetes_service_v1.rds_core_writer,
    kubernetes_service_v1.rds_reservation_writer,
  ]
}
