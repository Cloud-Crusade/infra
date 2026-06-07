terraform {
  required_version = ">= 1.15.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

module "vpc" {
  source = "../../modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  enable_nat_gateway   = var.enable_nat_gateway
}

module "security_groups" {
  source            = "../../modules/security_group"
  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  vpc_cidr          = var.vpc_cidr
  allowed_ssh_cidrs = var.allowed_ssh_cidrs
}
module "secrets_manager" {
  source                        = "../../modules/secrets_manager"
  project_name                  = var.project_name
  environment                   = var.environment
  authorization_secret_value    = random_password.authorization.result
  reservation_private_key_value = tls_private_key.reservation.private_key_pem
  rds_username                  = var.db_username
  rds_password                  = var.db_password
  core_writer_endpoint          = module.rds.primary_endpoint
  reservation_writer_endpoint   = module.rds.reservation_endpoint
}
module "iam" {
  source            = "../../modules/iam"
  project_name      = var.project_name
  environment       = var.environment
  oidc_provider_arn = var.oidc_provider_arn
  oidc_provider_url = var.oidc_provider_url
}
module "rds" {
  source                 = "../../modules/rds"
  project_name           = var.project_name
  environment            = var.environment
  db_name                = var.db_name
  db_username            = var.db_username
  db_password            = var.db_password
  instance_class         = var.db_instance_class
  engine_version         = var.db_engine_version
  allocated_storage      = var.db_allocated_storage
  vpc_security_group_ids = [module.security_groups.rds_sg_id]
  azs                    = var.availability_zones
  subnet_ids             = module.vpc.private_subnet_ids
}
module "cloudfront" {
  source       = "../../modules/cloudfront"
  project_name = var.project_name
  environment  = var.environment
  # web 정적 호스팅 + JWT 공개키가 같은 public 버킷 → CloudFront 로 접근 비용 절감
  s3_bucket_name                 = var.public_bucket
  s3_bucket_regional_domain_name = "${var.public_bucket}.s3.${var.aws_region}.amazonaws.com"
}

# 예약 데이터 임시 큐 (서비스 produce → persistence 람다 consume)
module "sqs" {
  source       = "../../modules/sqs"
  project_name = var.project_name
  environment  = var.environment
  name         = "reservation-leaky-bucket"
}

# SQS(예약 큐) → persistence 람다 트리거
resource "aws_lambda_event_source_mapping" "persistence_sqs" {
  event_source_arn = module.sqs.queue_arn
  function_name    = module.lambda.function_arns["persistence"]
}

# Lambda — zip/목록은 S3, 모듈별 env 주입 (값은 GitHub env→converter 수신)
module "lambda" {
  source          = "../../modules/lambda"
  project_name    = var.project_name
  environment     = var.environment
  lambda_role_arn = module.iam.lambda_role_arn
  artifact_bucket = "tfstate-bucket-d8f5bb8d"

  # ticketing → ElastiCache, persistence → RDS (VPC 내부). authorizer 는 CloudFront 접근 위해 VPC 제외
  vpc_modules            = ["ticketing", "persistence"]
  vpc_subnet_ids         = module.vpc.private_subnet_ids
  vpc_security_group_ids = [module.security_groups.lambda_sg_id]

  lambda_env = {
    persistence = {
      # SQS 로 받은 예약 데이터를 reservation RDS 에 적재(psycopg2). URL 은 rds 에서 구성
      RESERVATION_DB_URL = "postgresql://${var.db_username}:${var.db_password}@${module.rds.reservation_endpoint}/${var.db_name}"
    }
    ticketing = {
      REDIS_HOST = module.elasticache.main_cache_endpoint
      REDIS_PORT = "6379"
      # terraform 이 생성하는 예약 서명키(개인키) 주입 — 검증측은 S3 의 공개키 사용
      JWT_SECRET = tls_private_key.reservation.private_key_pem
    }
    # 예약 토큰 서명 검증 authorizer — CloudFront 로 reservation 공개키 fetch(RS256 검증)
    # S3 직접 접근 대신 CloudFront URL → S3 IAM 불필요 + 접근 비용 절감
    authorizer = {
      PUBLIC_KEY_URL = "https://${module.cloudfront.cloudfront_domain_name}/jwt/${var.environment}/reservation/public_key.pem"
    }
  }
}

# API Gateway — app/예약 백엔드는 테스트 EC2(ticketing-app), queue 는 ticketing 람다
module "apigateway" {
  source                     = "../../modules/apigateway"
  project_name               = var.project_name
  environment                = var.environment
  app_backend_url            = "http://${aws_instance.test_service.public_dns}:${var.test_service_port}"
  reservation_backend_url    = "http://${aws_instance.test_service.public_dns}:${var.test_service_port}"
  queue_lambda_invoke_arn    = module.lambda.invoke_arns["ticketing"]
  queue_lambda_function_name = module.lambda.function_names["ticketing"]

  authorizer_lambda_invoke_arn    = module.lambda.invoke_arns["authorizer"]
  authorizer_lambda_function_name = module.lambda.function_names["authorizer"]
}

# ElastiCache (Redis/Valkey) — 서브넷그룹은 모듈 내부 생성, SG 는 security_group 모듈
module "elasticache" {
  source            = "../../modules/elasticache"
  subnet_group_name = "${var.project_name}-${var.environment}-cache"
  subnet_ids        = module.vpc.private_subnet_ids

  main_cache_replication_group_id = "${var.project_name}-${var.environment}-main-cache"
  main_cache_engine               = "valkey"
  main_cache_engine_version       = "8.0"
  main_cache_parameter_group_name = "default.valkey8"
  main_cache_node_type            = "cache.t3.micro"
  main_cache_port                 = 6379
  main_cache_num_clusters         = 1
  main_cache_sg_id                = module.security_groups.cache_sg_id

  waiting_room_replication_group_id   = "${var.project_name}-${var.environment}-waiting-room"
  waiting_room_engine                 = "redis"
  waiting_room_engine_version         = "7.1"
  waiting_room_parameter_group_family = "redis7"
  waiting_room_node_type              = "cache.t3.micro"
  waiting_room_port                   = 6379
  waiting_room_num_clusters           = 1
  waiting_room_sg_id                  = module.security_groups.cache_sg_id
}