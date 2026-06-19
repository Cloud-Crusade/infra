locals {
  ticketing_namespace = "ticketing"

  # DB_*_URL/REDIS_URL 호스트로 쓰는 클러스터 내부 고정 DNS(ExternalName) 의 실제 타깃.
  # RDS 엔드포인트는 host:port 형식이라 포트 분리
  db_core_writer_host        = split(":", var.rds_core_writer_endpoint)[0]
  db_core_reader_host        = split(":", var.rds_core_reader_endpoint)[0]
  db_reservation_writer_host = split(":", var.rds_reservation_writer_endpoint)[0]
  db_reservation_reader_host = split(":", var.rds_reservation_reader_endpoint)[0]
  redis_main_host            = var.redis_main_endpoint

  # gRPC 포트 단일 소스 — ConfigMap·클라이언트 타깃·service 모듈이 공유
  grpc_port = 50051

  # gRPC 클라이언트 타깃 (headless Service + dns:/// round_robin)
  svc_grpc_targets = {
    reservation = { EVENT_GRPC_TARGET = "dns:///event-grpc:${local.grpc_port}" }
    payment     = { RESERVATION_GRPC_TARGET = "dns:///reservation-grpc:${local.grpc_port}" }
  }
}

resource "kubernetes_namespace_v1" "ticketing" {
  metadata {
    name = local.ticketing_namespace
  }
}

# 4서비스 공통 비밀(비-DB) — DB 크리덴셜은 서비스별 Secret(db_roles.tf) 로 분리
resource "kubernetes_secret_v1" "ticketing_secrets" {
  metadata {
    name      = "ticketing-secrets"
    namespace = local.ticketing_namespace
  }
  data = {
    JWT_SECRET          = var.jwt_secret
    CAPTCHA_HMAC_SECRET = var.captcha_hmac_secret
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
    ENV        = "development"
    AWS_REGION = var.aws_region

    REDIS_URL                           = "redis://redis-main:6379/0"
    REDIS_HEALTH_CHECK_INTERVAL_SECONDS = "30"
    DB_POOL_RECYCLE_SECONDS             = "1800"

    SQS_RESERVATION_QUEUE_URL = var.sqs_queue_url

    GRPC_PORT          = tostring(local.grpc_port)
    CAPTCHA_ENABLED    = tostring(var.captcha_enabled)
    CORS_ALLOW_ORIGINS = jsonencode(["https://www.${var.domain_name}"])
  }
  depends_on = [kubernetes_namespace_v1.ticketing]
}

# 엔드포인트 컷오버 대비 — 앱은 아래 고정 서비스명을 DB/Redis 호스트로 사용하고,
# 실제 RDS/ElastiCache 가 바뀌면 ExternalName 타깃만 갱신(앱 env·재시작 불필요).
resource "kubernetes_service_v1" "rds_core_writer" {
  metadata {
    name      = "rds-core-writer"
    namespace = local.ticketing_namespace
  }
  spec {
    type          = "ExternalName"
    external_name = local.db_core_writer_host
  }
  depends_on = [kubernetes_namespace_v1.ticketing]
}

resource "kubernetes_service_v1" "rds_core_reader" {
  metadata {
    name      = "rds-core-reader"
    namespace = local.ticketing_namespace
  }
  spec {
    type          = "ExternalName"
    external_name = local.db_core_reader_host
  }
  depends_on = [kubernetes_namespace_v1.ticketing]
}

resource "kubernetes_service_v1" "rds_reservation_writer" {
  metadata {
    name      = "rds-reservation-writer"
    namespace = local.ticketing_namespace
  }
  spec {
    type          = "ExternalName"
    external_name = local.db_reservation_writer_host
  }
  depends_on = [kubernetes_namespace_v1.ticketing]
}

resource "kubernetes_service_v1" "rds_reservation_reader" {
  metadata {
    name      = "rds-reservation-reader"
    namespace = local.ticketing_namespace
  }
  spec {
    type          = "ExternalName"
    external_name = local.db_reservation_reader_host
  }
  depends_on = [kubernetes_namespace_v1.ticketing]
}

resource "kubernetes_service_v1" "redis_main" {
  metadata {
    name      = "redis-main"
    namespace = local.ticketing_namespace
  }
  spec {
    type          = "ExternalName"
    external_name = local.redis_main_host
  }
  depends_on = [kubernetes_namespace_v1.ticketing]
}

# SQS produce 서비스(reservation·payment) → IRSA 로 SendMessage 권한. 나머지 서비스는 권한 불필요.
# (payment 도 결제 이벤트를 SQS publish 하므로 reservation 과 함께 포함 — 미포함 시 NoCredentialsError→500)
# OIDC provider 는 이 모듈이 생성하므로 내부 리소스 직접 참조(issuer 의 https:// 제거 후 sub 컨디션)
locals {
  sqs_producers = ["reservation", "payment"]
}

data "aws_iam_policy_document" "svc_irsa_assume" {
  for_each = toset(local.sqs_producers)
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${local.ticketing_namespace}:ticketing-${each.key}"]
    }
  }
}

resource "aws_iam_role" "svc_irsa" {
  for_each           = toset(local.sqs_producers)
  name               = "${var.project_name}-${var.environment}-ticketing-${each.key}-irsa"
  assume_role_policy = data.aws_iam_policy_document.svc_irsa_assume[each.key].json
}

resource "aws_iam_role_policy" "svc_sqs" {
  for_each = toset(local.sqs_producers)
  name     = "sqs-send"
  role     = aws_iam_role.svc_irsa[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sqs:SendMessage", "sqs:GetQueueUrl", "sqs:GetQueueAttributes"]
      Resource = var.sqs_queue_arn
    }]
  })
}

# 기존 reservation 전용 리소스 → producer 집합으로 일반화(물리 동일, state 주소만 이전)
moved {
  from = aws_iam_role.reservation_irsa
  to   = aws_iam_role.svc_irsa["reservation"]
}
moved {
  from = aws_iam_role_policy.reservation_sqs
  to   = aws_iam_role_policy.svc_sqs["reservation"]
}

module "ticketing_service" {
  source   = "./service"
  for_each = local.svc_db

  name      = each.key
  namespace = local.ticketing_namespace
  image     = local.ticketing_images[each.key]

  # AZ 분산을 위해 서비스별 최소 2 파드(zone topologySpread 와 함께 양 AZ 병렬 배치)
  replicas     = 2
  min_replicas = 2
  max_replicas = 4

  grpc_enabled = contains(["event", "reservation"], each.key)
  grpc_port    = local.grpc_port

  config_map_refs = [kubernetes_config_map_v1.ticketing_config.metadata[0].name]
  secret_refs = [
    kubernetes_secret_v1.ticketing_secrets.metadata[0].name,
    kubernetes_secret_v1.ticketing_db[each.key].metadata[0].name,
  ]

  extra_env = lookup(local.svc_grpc_targets, each.key, {})

  irsa_role_arn = contains(local.sqs_producers, each.key) ? aws_iam_role.svc_irsa[each.key].arn : ""

  depends_on = [kubernetes_job_v1.db_bootstrap]
}
