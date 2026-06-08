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
  source                          = "../../modules/secrets_manager"
  project_name                    = var.project_name
  environment                     = var.environment
  authorization_private_key_value = tls_private_key.authorization.private_key_pem
  reservation_private_key_value   = tls_private_key.reservation.private_key_pem
  rds_username                    = var.db_username
  rds_password                    = var.db_password
  core_writer_endpoint            = module.rds.primary_endpoint
  reservation_writer_endpoint     = module.rds.reservation_endpoint
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
  source                         = "../../modules/cloudfront"
  project_name                   = var.project_name
  environment                    = var.environment
  s3_bucket_name                 = var.s3_bucket_name
  s3_bucket_regional_domain_name = var.s3_bucket_regional_domain_name
}
module "cloudwatch" {
  source = "../../modules/cloudwatch"

  project_name = var.project_name
  environment  = var.environment
  alarm_email  = var.alarm_email

  # RDS
  rds_instance_ids = [
    "${var.project_name}-${var.environment}-primary",
    "${var.project_name}-${var.environment}-primary-replica",
    "${var.project_name}-${var.environment}-reservation",
    "${var.project_name}-${var.environment}-reservation-replica",
    "${var.project_name}-${var.environment}-reservation-replica-2",
  ]

  # Lambda (모듈 연결 후 활성화)
  lambda_function_names = [
    "${var.project_name}-${var.environment}-authorizer",
    "${var.project_name}-${var.environment}-ticketing",
    "${var.project_name}-${var.environment}-persistence",
  ]

  # CloudFront
  cloudfront_distribution_id = ""

  # ElastiCache (틀만 — 모듈 연결 후 활성화)
  elasticache_cluster_ids = []

  # SQS (틀만 — 모듈 연결 후 활성화)
  sqs_queue_names = []

  # EKS (틀만 — 모듈 연결 후 활성화)
  eks_cluster_name = ""

  # API Gateway (틀만 — 모듈 연결 후 활성화)
  api_gateway_name = ""
}
