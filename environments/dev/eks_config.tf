# 4서비스 공통 비밀(비-DB) — DB 크리덴셜은 서비스별 Secret(eks_db_roles.tf) 로 분리
resource "kubernetes_secret_v1" "ticketing_secrets" {
  metadata {
    name      = "ticketing-secrets"
    namespace = local.ticketing_namespace
  }
  data = {
    # 검증측(API GW authorizer)과 공유하는 HS256 대칭키
    JWT_SECRET          = random_password.authorization.result
    CAPTCHA_HMAC_SECRET = random_password.captcha_hmac.result
  }
  depends_on = [kubernetes_namespace_v1.ticketing]
}

# 4서비스 공통 비-비밀 env. 서비스별 DB_*_URL/gRPC 타깃은 per-svc ConfigMap·Secret 에서 주입
resource "kubernetes_config_map_v1" "ticketing_config" {
  metadata {
    name      = "ticketing-config"
    namespace = local.ticketing_namespace
  }
  data = {
    # 클러스터에선 스키마를 alembic 이 소유(앱 자동 create_all 비활성) + JSON 로그(Fluent Bit→CloudWatch)
    ENV        = "production"
    AWS_REGION = var.aws_region

    REDIS_URL                           = "redis://redis-main:6379/0"
    REDIS_HEALTH_CHECK_INTERVAL_SECONDS = "30"
    DB_POOL_RECYCLE_SECONDS             = "1800"

    SQS_RESERVATION_QUEUE_URL = module.sqs.queue_url

    GRPC_PORT          = "50051"
    CAPTCHA_ENABLED    = tostring(var.captcha_enabled)
    CORS_ALLOW_ORIGINS = jsonencode(["https://www.${var.domain_name}"])
  }
  depends_on = [kubernetes_namespace_v1.ticketing]
}
