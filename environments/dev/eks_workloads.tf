locals {
  ticketing_namespace = "ticketing"

  # DB_*_URL/REDIS_URL 호스트로 쓰는 클러스터 내부 고정 DNS(ExternalName) 의 실제 타깃.
  # RDS 엔드포인트는 host:port 형식이라 포트 분리
  db_core_writer_host        = split(":", module.rds.primary_endpoint)[0]
  db_core_reader_host        = split(":", module.rds.primary_replica_endpoint)[0]
  db_reservation_writer_host = split(":", module.rds.reservation_endpoint)[0]
  db_reservation_reader_host = split(":", module.rds.reservation_replica_endpoint)[0]
  redis_main_host            = module.elasticache.main_cache_endpoint
}

resource "kubernetes_namespace_v1" "ticketing" {
  metadata {
    name = local.ticketing_namespace
  }
}

locals {
  # gRPC 클라이언트 타깃 (headless Service + dns:/// round_robin)
  svc_grpc_targets = {
    reservation = { EVENT_GRPC_TARGET = "dns:///event-grpc:50051" }
    payment     = { RESERVATION_GRPC_TARGET = "dns:///reservation-grpc:50051" }
  }
}

# reservation 만 SQS produce → IRSA 로 SendMessage 권한 (나머지 서비스는 권한 불필요)
data "aws_iam_policy_document" "reservation_irsa_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${local.ticketing_namespace}:ticketing-reservation"]
    }
  }
}

resource "aws_iam_role" "reservation_irsa" {
  name               = "${var.project_name}-${var.environment}-ticketing-reservation-irsa"
  assume_role_policy = data.aws_iam_policy_document.reservation_irsa_assume.json
}

resource "aws_iam_role_policy" "reservation_sqs" {
  name = "sqs-send"
  role = aws_iam_role.reservation_irsa.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sqs:SendMessage", "sqs:GetQueueUrl", "sqs:GetQueueAttributes"]
      Resource = module.sqs.queue_arn
    }]
  })
}

module "ticketing_service" {
  source   = "../../modules/eks_service"
  for_each = local.svc_db

  name      = each.key
  namespace = local.ticketing_namespace
  image     = "${aws_ecr_repository.ticketing[each.key].repository_url}:${var.ticketing_image_tag}"

  replicas     = 1
  min_replicas = 1
  max_replicas = 3

  grpc_enabled = contains(["event", "reservation"], each.key)

  config_map_refs = [kubernetes_config_map_v1.ticketing_config.metadata[0].name]
  secret_refs = [
    kubernetes_secret_v1.ticketing_secrets.metadata[0].name,
    kubernetes_secret_v1.ticketing_db[each.key].metadata[0].name,
  ]

  extra_env = lookup(local.svc_grpc_targets, each.key, {})

  irsa_role_arn = each.key == "reservation" ? aws_iam_role.reservation_irsa.arn : ""

  depends_on = [kubernetes_job_v1.migrate]
}
