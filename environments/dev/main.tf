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
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
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
  # VPC 내부 ticketing 람다가 NAT 없이 Secrets Manager 조회(인터페이스 엔드포인트)
  enable_secretsmanager_endpoint = true
}

# SM 엔드포인트 인바운드(443) — 실제 SM 접근이 필요한 lambda SG 만 허용(최소권한, 모듈 순환 회피)
resource "aws_security_group_rule" "sm_endpoint_from_lambda" {
  type                     = "ingress"
  security_group_id        = module.vpc.secretsmanager_endpoint_security_group_id
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
  vpc_id            = module.vpc.vpc_id
  vpc_cidr          = module.vpc.vpc_cidr
  allowed_ssh_cidrs = var.allowed_ssh_cidrs
}

module "eks" {
  source = "../../modules/eks"

  project_name = var.project_name
  environment  = var.environment
  subnet_ids   = module.vpc.private_subnet_ids

  additional_security_group_ids = [module.security_groups.eks_sg_id]

  cluster_version = var.eks_cluster_version

  # TODO: 환경별 엔드포인트 접근 정책 설정
  cluster_endpoint_public_access       = var.eks_endpoint_public_access
  cluster_endpoint_private_access      = var.eks_endpoint_private_access
  cluster_endpoint_public_access_cidrs = var.eks_endpoint_public_access_cidrs

  cluster_enabled_log_types = var.eks_enabled_log_types

  # system 노드 그룹
  system_ng_instance_types = var.eks_system_ng_instance_types
  system_ng_capacity_type  = var.eks_system_ng_capacity_type
  system_ng_desired_size   = var.eks_system_ng_desired_size
  system_ng_min_size       = var.eks_system_ng_min_size
  system_ng_max_size       = var.eks_system_ng_max_size

  # app 노드 그룹
  app_ng_instance_types = var.eks_app_ng_instance_types
  app_ng_capacity_type  = var.eks_app_ng_capacity_type
  app_ng_desired_size   = var.eks_app_ng_desired_size
  app_ng_min_size       = var.eks_app_ng_min_size
  app_ng_max_size       = var.eks_app_ng_max_size

  # IAM ARN
  cluster_role_arn = module.iam.cluster_role_arn
  node_role_arn    = module.iam.ng_role_arn
  vpc_cni_role_arn = module.iam.vpc_cni_role_arn
  ebs_csi_role_arn = module.iam.ebs_csi_role_arn

  access_entries = var.eks_access_entries

  # ----- MSA 워크로드 배선 (Deployment·Service·HPA·SA·DB롤·마이그레이션) -----
  aws_region          = var.aws_region
  domain_name         = var.domain_name
  captcha_enabled     = var.captcha_enabled
  ticketing_image_tag = var.ticketing_image_tag
  # 리포지토리(ticketing-<svc>)는 terraform 밖에서 선행 생성 → 레지스트리 호스트만 전달
  ecr_registry = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"

  # RDS/ElastiCache 고정 DNS(ExternalName) 타깃 — 엔드포인트 컷오버 시 타깃만 갱신
  rds_core_writer_endpoint        = module.rds.primary_endpoint
  rds_core_reader_endpoint        = module.rds.primary_replica_endpoint
  rds_reservation_writer_endpoint = module.rds.reservation_endpoint
  rds_reservation_reader_endpoint = module.rds.reservation_replica_endpoint
  redis_main_endpoint             = module.elasticache.main_cache_endpoint

  # reservation IRSA(SendMessage) + ConfigMap 큐 URL
  sqs_queue_url = module.sqs.queue_url
  sqs_queue_arn = module.sqs.queue_arn

  # 검증측(authorizer)과 공유하는 시크릿 — 루트가 random_password 소유
  jwt_secret          = random_password.authorization.result
  captcha_hmac_secret = random_password.captcha_hmac.result

  # 서비스별 DB 롤 부트스트랩(master 크리덴셜)
  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password
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
  captcha_hmac_secret_value     = random_password.captcha_hmac.result
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
# www 커스텀 도메인용 ACM 인증서 — CloudFront 는 us-east-1 인증서만 허용
module "acm_www" {
  source = "../../modules/acm"
  providers = {
    aws = aws.us_east_1
  }

  domain_name     = "www.${var.domain_name}"
  route53_zone_id = var.route53_zone_id
}

module "cloudfront" {
  source       = "../../modules/cloudfront"
  project_name = var.project_name
  environment  = var.environment
  # web 정적 호스팅 + JWT 공개키가 같은 public 버킷 → CloudFront 로 접근 비용 절감
  s3_bucket_name                 = var.public_bucket
  s3_bucket_regional_domain_name = var.public_bucket_domain_name

  # www 커스텀 도메인 + us-east-1 ACM 인증서
  aliases             = ["www.${var.domain_name}"]
  acm_certificate_arn = module.acm_www.certificate_arn
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
      REDIS_HOST = module.elasticache.waiting_room_cache_endpoint
      REDIS_PORT = "6379"
      # 예약 서명키(RSA 개인키)는 값이 아닌 이름만 — 런타임에 Secrets 확장 캐시로 조회(VPC 엔드포인트 경유)
      RESERVATION_SECRET_ID = module.secrets_manager.reservation_private_key_secret_arn
      # access token(HS256) 검증용 — 큐가 sub→user_id 추출. authorizer 와 동일 시크릿
      AUTHORIZATION_SECRET_ID = module.secrets_manager.authorization_secret_arn
    }
    # 예약 토큰 서명 검증 authorizer — CloudFront 로 reservation 공개키 fetch(RS256 검증)
    # S3 직접 접근 대신 CloudFront URL → S3 IAM 불필요 + 접근 비용 절감
    authorizer = {
      PUBLIC_KEY_URL = "https://${module.cloudfront.cloudfront_domain_name}/jwt/${var.environment}/reservation/public_key.pem"
      # Authorization 대칭키(HS256) — 값이 아닌 이름만, 런타임에 Secrets 확장 캐시로 조회
      AUTHORIZATION_SECRET_ARN = module.secrets_manager.authorization_secret_arn
    }
    # captcha — HMAC 시크릿은 값이 아닌 이름만 주입, 런타임에 Secrets 확장 캐시로 조회
    captcha = {
      CAPTCHA_SECRET_ID = "${var.environment}-captcha-hmac-secret"
    }
  }

  # Secrets Manager 를 런타임 조회하는 Lambda 에 확장 레이어 부착 — 시크릿 캐시(호출 수·비용 절감)
  layers = {
    captcha    = [var.secrets_extension_layer_arn]
    authorizer = [var.secrets_extension_layer_arn]
    ticketing  = [var.secrets_extension_layer_arn]
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

  # captcha Lambda 가 배포(lambda-modules.txt 등록)됐을 때만 라우트 생성 — 미배포 시 plan 실패 방지
  enable_captcha_route         = contains(keys(module.lambda.function_names), "captcha")
  captcha_lambda_invoke_arn    = lookup(module.lambda.invoke_arns, "captcha", "")
  captcha_lambda_function_name = lookup(module.lambda.function_names, "captcha", "")

  authorizer_lambda_invoke_arn    = module.lambda.invoke_arns["authorizer"]
  authorizer_lambda_function_name = module.lambda.function_names["authorizer"]

  # 커스텀 도메인 (api.<domain>) — REGIONAL + ACM(DNS 검증, 기존 존 사용)
  api_domain_name = "api.${var.domain_name}"
  route53_zone_id = var.route53_zone_id
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

  blacklist_replication_group_id   = "${var.project_name}-${var.environment}-blacklist"
  blacklist_engine                 = "redis"
  blacklist_engine_version         = "7.1"
  blacklist_parameter_group_family = "redis7"
  blacklist_node_type              = "cache.t3.micro"
  blacklist_port                   = 6379
  blacklist_num_clusters           = 1
  blacklist_sg_id                  = module.security_groups.cache_sg_id
}

# Route53 레코드 — www → CloudFront(클라이언트), api → ALB(서버)
# 호스팅 영역은 기존 존 참조(route53_zone_id). api 는 apigateway 커스텀 도메인(REGIONAL) 출력으로 연결.
module "route53" {
  source = "../../modules/route53"

  domain_name     = var.domain_name
  route53_zone_id = var.route53_zone_id

  # www → CloudFront (클라이언트 정적 호스팅)
  cloudfront_domain_name = module.cloudfront.cloudfront_domain_name
  cloudfront_zone_id     = var.cloudfront_zone_id

  # api → API Gateway 커스텀 도메인 (REGIONAL)
  api_target_dns_name = module.apigateway.domain_regional_target
  api_target_zone_id  = module.apigateway.domain_regional_zone_id
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
    module.lambda.function_names["authorizer"],
    module.lambda.function_names["ticketing"],
    module.lambda.function_names["persistence"],
  ]

  # CloudFront
  cloudfront_distribution_id = module.cloudfront.cloudfront_distribution_id

  # ElastiCache
  elasticache_cluster_ids = [
    module.elasticache.main_cache_cluster_id,
    module.elasticache.waiting_room_cache_cluster_id,
  ]

  # SQS
  sqs_queue_names = [module.sqs.queue_name]

  # EKS (틀만 — 모듈 연결 후 활성화)
  eks_cluster_name = ""

  # API Gateway (틀만 — 모듈 연결 후 활성화)
  api_gateway_name = ""
}

module "nlb" {
  source = "../../modules/nlb"

  project_name = var.project_name
  environment  = var.environment
  subnet_ids   = module.vpc.private_subnet_ids
}

module "prometheus" {
  source = "../../modules/prometheus"

  project_name = var.project_name
  environment  = var.environment

  # EKS (틀만 — 모듈 연결 후 활성화)
  eks_cluster_name = ""
}

module "eventbridge" {
  source = "../../modules/eventbridge"

  project_name = var.project_name
  environment  = var.environment
}