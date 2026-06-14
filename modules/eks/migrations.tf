# 서비스별 스키마 마이그레이션 — 자기 롤로 alembic upgrade head (테이블 소유권 격리)
# 이미지가 ECR 에 push 되기 전(최초 apply) apply 를 막지 않도록 wait_for_completion=false.
# 롤 부트스트랩 완료 후 생성되며, 이미지 도착 시 실행된다.
resource "kubernetes_job_v1" "migrate" {
  for_each = local.svc_db

  metadata {
    name      = "ticketing-${each.key}-migrate"
    namespace = local.ticketing_namespace
  }
  spec {
    backoff_limit = 3
    template {
      metadata {
        labels = { app = "ticketing-${each.key}-migrate" }
      }
      spec {
        restart_policy = "OnFailure"

        toleration {
          key      = "dedicated"
          value    = "app"
          operator = "Equal"
          effect   = "NoSchedule"
        }
        node_selector = { role = "app" }

        container {
          name    = "migrate"
          image   = "${var.ecr_repository_urls[each.key]}:${var.ticketing_image_tag}"
          command = ["uv", "run", "--package", "cc-${each.key}", "alembic", "-c", "services/${each.key}/alembic/alembic.ini", "upgrade", "head"]

          env_from {
            config_map_ref { name = kubernetes_config_map_v1.ticketing_config.metadata[0].name }
          }
          env_from {
            secret_ref { name = kubernetes_secret_v1.ticketing_secrets.metadata[0].name }
          }
          env_from {
            secret_ref { name = kubernetes_secret_v1.ticketing_db[each.key].metadata[0].name }
          }
        }
      }
    }
  }

  wait_for_completion = false

  depends_on = [kubernetes_job_v1.db_bootstrap]
}
