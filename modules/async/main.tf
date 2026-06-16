module "sqs" {
  source       = "./sqs"
  project_name = var.project_name
  environment  = var.environment
  name         = "reservation-leaky-bucket"
}

module "eventbridge" {
  source       = "./eventbridge"
  project_name = var.project_name
  environment  = var.environment
}

module "lambda" {
  source          = "./lambda"
  project_name    = var.project_name
  environment     = var.environment
  lambda_role_arn = var.lambda_role_arn
  artifact_bucket = "tfstate-bucket-d8f5bb8d"

  # ticketing → ElastiCache, persistence → RDS (VPC 내부). authorizer 는 CloudFront 접근 위해 VPC 제외
  vpc_modules            = ["ticketing", "persistence"]
  vpc_subnet_ids         = var.vpc_subnet_ids
  vpc_security_group_ids = [var.lambda_sg_id]

  lambda_env = {
    persistence = {
      RESERVATION_DB_URL = "postgresql://${var.db_username}:${var.db_password}@${var.reservation_endpoint}/${var.db_name}"
    }
    ticketing = {
      REDIS_HOST = var.waiting_room_cache_endpoint
      REDIS_PORT = "6379"
      # 시크릿은 값이 아닌 이름만 — 런타임에 Secrets 확장 캐시로 조회(VPC 엔드포인트 경유)
      RESERVATION_SECRET_ID   = var.reservation_private_key_secret_arn
      AUTHORIZATION_SECRET_ID = var.authorization_secret_arn
    }
    # 예약 토큰 검증 authorizer — CloudFront URL 로 reservation 공개키 fetch(S3 IAM 불필요)
    authorizer = {
      PUBLIC_KEY_URL           = "https://${var.cloudfront_domain_name}/jwt/${var.environment}/reservation/public_key.pem"
      AUTHORIZATION_SECRET_ARN = var.authorization_secret_arn
    }
    captcha = {
      CAPTCHA_SECRET_ID = "${var.environment}-captcha-hmac-secret"
    }
  }

  # Secrets Manager 런타임 조회 Lambda 에 확장 레이어 부착 — 시크릿 캐시(호출 수·비용 절감)
  layers = {
    captcha    = [var.secrets_extension_layer_arn]
    authorizer = [var.secrets_extension_layer_arn]
    ticketing  = [var.secrets_extension_layer_arn]
  }
}

# SQS(예약 큐) → persistence 람다 트리거
resource "aws_lambda_event_source_mapping" "persistence_sqs" {
  event_source_arn = module.sqs.queue_arn
  function_name    = module.lambda.function_arns["persistence"]
}
