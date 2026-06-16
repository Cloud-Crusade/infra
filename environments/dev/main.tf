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
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
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

# CloudFront 인증서는 us-east-1 ACM 만 허용 → 별도 provider alias
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

provider "helm" {
  kubernetes = {
    host                   = module.cluster.cluster_endpoint
    cluster_ca_certificate = base64decode(module.cluster.cluster_ca_data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.cluster.cluster_name]
    }
  }
}

provider "kubernetes" {
  host                   = module.cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.cluster.cluster_ca_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.cluster.cluster_name]
  }
}

module "network" {
  source = "../../modules/network"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  enable_nat_gateway   = var.enable_nat_gateway
  # VPC 내부 ticketing 람다가 NAT 없이 Secrets Manager 조회(인터페이스 엔드포인트)
  enable_secretsmanager_endpoint = true
}


# SM 엔드포인트 인바운드(443) — 실제 SM 접근이 필요한 lambda SG 만 허용(최소권한, 모듈 순환 회피)
resource "aws_security_group_rule" "sm_endpoint_from_lambda" {
  type                     = "ingress"
  security_group_id        = module.network.secretsmanager_endpoint_security_group_id
  source_security_group_id = module.security_groups.lambda_sg_id
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  description              = "SM endpoint inbound from lambda SG"
}

module "security_groups" {
  source            = "../../modules/security_group"
  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.network.vpc_id
  vpc_cidr          = module.network.vpc_cidr
  allowed_ssh_cidrs = var.allowed_ssh_cidrs
}

module "cluster" {
  source = "../../modules/cluster"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region
  vpc_id       = module.network.vpc_id

  subnet_ids = module.network.private_subnet_ids
  eks_sg_id  = module.security_groups.eks_sg_id

  cluster_version                      = var.eks_cluster_version
  cluster_endpoint_public_access       = var.eks_endpoint_public_access
  cluster_endpoint_private_access      = var.eks_endpoint_private_access
  cluster_endpoint_public_access_cidrs = var.eks_endpoint_public_access_cidrs
  cluster_enabled_log_types            = var.eks_enabled_log_types
  access_entries                       = var.eks_access_entries

  system_ng_instance_types = var.eks_system_ng_instance_types
  system_ng_capacity_type  = var.eks_system_ng_capacity_type
  system_ng_desired_size   = var.eks_system_ng_desired_size
  system_ng_min_size       = var.eks_system_ng_min_size
  system_ng_max_size       = var.eks_system_ng_max_size

  app_ng_instance_types = var.eks_app_ng_instance_types
  app_ng_capacity_type  = var.eks_app_ng_capacity_type
  app_ng_desired_size   = var.eks_app_ng_desired_size
  app_ng_min_size       = var.eks_app_ng_min_size
  app_ng_max_size       = var.eks_app_ng_max_size

  cluster_role_arn = module.iam.cluster_role_arn
  node_role_arn    = module.iam.ng_role_arn
  vpc_cni_role_arn = module.iam.vpc_cni_role_arn
  ebs_csi_role_arn = module.iam.ebs_csi_role_arn

  domain_name         = var.domain_name
  captcha_enabled     = var.captcha_enabled
  ticketing_image_tag = var.ticketing_image_tag
  # 리포지토리(ticketing-<svc>)는 terraform 밖에서 선행 생성 → 레지스트리 호스트만 전달
  ecr_registry = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"

  rds_core_writer_endpoint        = module.data.primary_endpoint
  rds_core_reader_endpoint        = module.data.primary_replica_endpoint
  rds_reservation_writer_endpoint = module.data.reservation_endpoint
  rds_reservation_reader_endpoint = module.data.reservation_replica_endpoint
  redis_main_endpoint             = module.data.main_cache_endpoint

  sqs_queue_url = module.async.queue_url
  sqs_queue_arn = module.async.queue_arn

  jwt_secret          = random_password.authorization.result
  captcha_hmac_secret = random_password.captcha_hmac.result

  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password
}

module "data" {
  source = "../../modules/data"

  project_name       = var.project_name
  environment        = var.environment
  subnet_ids         = module.network.private_subnet_ids
  availability_zones = var.availability_zones
  rds_sg_id          = module.security_groups.rds_sg_id
  cache_sg_id        = module.security_groups.cache_sg_id

  db_name              = var.db_name
  db_username          = var.db_username
  db_password          = var.db_password
  db_instance_class    = var.db_instance_class
  db_engine_version    = var.db_engine_version
  db_allocated_storage = var.db_allocated_storage

  authorization_secret_value    = random_password.authorization.result
  reservation_private_key_value = tls_private_key.reservation.private_key_pem
  captcha_hmac_secret_value     = random_password.captcha_hmac.result
}

module "iam" {
  source            = "../../modules/iam"
  project_name      = var.project_name
  environment       = var.environment
  oidc_provider_arn = var.oidc_provider_arn
  oidc_provider_url = var.oidc_provider_url
}
# 클라이언트 정적 호스팅(CloudFront + www ACM). acm_www 는 us-east-1 전용 → aliased provider 전달
module "frontend" {
  source = "../../modules/frontend"
  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  project_name              = var.project_name
  environment               = var.environment
  domain_name               = var.domain_name
  route53_zone_id           = var.route53_zone_id
  public_bucket             = var.public_bucket
  public_bucket_domain_name = var.public_bucket_domain_name
}


# 비동기/서버리스 — lambda·sqs·eventbridge + persistence SQS→Lambda 트리거
module "async" {
  source = "../../modules/async"

  project_name = var.project_name
  environment  = var.environment

  lambda_role_arn             = module.iam.lambda_role_arn
  lambda_sg_id                = module.security_groups.lambda_sg_id
  vpc_subnet_ids              = module.network.private_subnet_ids
  secrets_extension_layer_arn = var.secrets_extension_layer_arn

  reservation_endpoint               = module.data.reservation_endpoint
  waiting_room_cache_endpoint        = module.data.waiting_room_cache_endpoint
  reservation_private_key_secret_arn = module.data.reservation_private_key_secret_arn
  authorization_secret_arn           = module.data.authorization_secret_arn
  cloudfront_domain_name             = module.frontend.cloudfront_domain_name

  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password
}


# 로그 그룹 소유 cloudwatch→lambda 이관 — 물리 그룹 동일, state 주소만 이동(재생성 없음)

# API 라우팅 — apigateway·nlb·route53. test_backend_url 은 ops 의 test_service, 백엔드 람다는 async
module "api" {
  source = "../../modules/api"

  project_name = var.project_name
  environment  = var.environment

  subnet_ids          = module.network.private_subnet_ids
  vpc_id              = module.network.vpc_id
  vpc_cidr            = module.network.vpc_cidr
  ticketing_http_port = var.ticketing_http_port

  api_backend      = var.api_backend
  test_backend_url = "http://${module.ops.test_service_public_dns}:${var.test_service_port}"

  lambda_invoke_arns    = module.async.invoke_arns
  lambda_function_names = module.async.function_names

  domain_name            = var.domain_name
  route53_zone_id        = var.route53_zone_id
  cloudfront_domain_name = module.frontend.cloudfront_domain_name
  cloudfront_zone_id     = var.cloudfront_zone_id
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

  # Lambda
  lambda_function_names = [
    module.async.function_names["authorizer"],
    module.async.function_names["ticketing"],
    module.async.function_names["persistence"],
  ]

  # CloudFront
  cloudfront_distribution_id = module.frontend.cloudfront_distribution_id

  # ElastiCache
  elasticache_cluster_ids = [
    module.data.main_cache_cluster_id,
    module.data.waiting_room_cache_cluster_id,
  ]

  # SQS
  sqs_queue_names = [module.async.queue_name]

  # EKS (틀만 — 모듈 연결 후 활성화)
  eks_cluster_name = ""

  # API Gateway (틀만 — 모듈 연결 후 활성화)
  api_gateway_name = ""
}

# NLB(ip 타겟) → 파드 수신 포트 — 클러스터 SG(관리형 노드그룹·파드 ENI)에 인바운드 허용
resource "aws_security_group_rule" "pods_from_nlb" {
  type                     = "ingress"
  security_group_id        = module.cluster.cluster_security_group_id
  source_security_group_id = module.api.nlb_sg_id
  from_port                = var.ticketing_http_port
  to_port                  = var.ticketing_http_port
  protocol                 = "tcp"
  description              = "ticketing pods from NLB"
}


# 운영/테스트 픽스처 — bastion(SSH·grafana) + test_ec2(디버그 백엔드)
module "ops" {
  source = "../../modules/ops"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  public_subnet_ids = module.network.public_subnet_ids
  vpc_id            = module.network.vpc_id
  bastion_sg_id     = module.security_groups.bastion_sg_id
  eks_sg_id         = module.security_groups.eks_sg_id
  allowed_ssh_cidrs = var.allowed_ssh_cidrs

  bastion_instance_type = var.bastion_instance_type

  rds_primary_endpoint             = module.data.primary_endpoint
  rds_primary_replica_endpoint     = module.data.primary_replica_endpoint
  rds_reservation_endpoint         = module.data.reservation_endpoint
  rds_reservation_replica_endpoint = module.data.reservation_replica_endpoint
  redis_main_endpoint              = module.data.main_cache_endpoint

  sqs_queue_url = module.async.queue_url
  sqs_queue_arn = module.async.queue_arn

  jwt_secret          = random_password.authorization.result
  captcha_hmac_secret = random_password.captcha_hmac.result
  captcha_enabled     = var.captcha_enabled

  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password

  test_image_registry        = var.test_image_registry
  ecr_namespace              = var.ecr_namespace
  test_image_tag             = var.test_image_tag
  test_service_port          = var.test_service_port
  test_ec2_instance_type     = var.test_ec2_instance_type
  test_ec2_root_volume_gb    = var.test_ec2_root_volume_gb
  test_service_ingress_cidrs = var.test_service_ingress_cidrs
}

