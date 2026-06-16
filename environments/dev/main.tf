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

moved {
  from = module.vpc
  to   = module.network.module.vpc
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

module "eks" {
  source = "../../modules/eks"

  project_name = var.project_name
  environment  = var.environment
  subnet_ids   = module.network.private_subnet_ids

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
  rds_core_writer_endpoint        = module.data.primary_endpoint
  rds_core_reader_endpoint        = module.data.primary_replica_endpoint
  rds_reservation_writer_endpoint = module.data.reservation_endpoint
  rds_reservation_reader_endpoint = module.data.reservation_replica_endpoint
  redis_main_endpoint             = module.data.main_cache_endpoint

  # reservation IRSA(SendMessage) + ConfigMap 큐 URL
  sqs_queue_url = module.async.queue_url
  sqs_queue_arn = module.async.queue_arn

  # 검증측(authorizer)과 공유하는 시크릿 — 루트가 random_password 소유
  jwt_secret          = random_password.authorization.result
  captcha_hmac_secret = random_password.captcha_hmac.result

  # 서비스별 DB 롤 부트스트랩(master 크리덴셜)
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

moved {
  from = module.rds
  to   = module.data.module.rds
}
moved {
  from = module.elasticache
  to   = module.data.module.elasticache
}
moved {
  from = module.secrets_manager
  to   = module.data.module.secrets_manager
}
module "iam" {
  source            = "../../modules/iam"
  project_name      = var.project_name
  environment       = var.environment
  oidc_provider_arn = var.oidc_provider_arn
  oidc_provider_url = var.oidc_provider_url
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
  cloudfront_domain_name             = module.cloudfront.cloudfront_domain_name

  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password
}

moved {
  from = module.lambda
  to   = module.async.module.lambda
}
moved {
  from = module.sqs
  to   = module.async.module.sqs
}
moved {
  from = module.eventbridge
  to   = module.async.module.eventbridge
}
moved {
  from = aws_lambda_event_source_mapping.persistence_sqs
  to   = module.async.aws_lambda_event_source_mapping.persistence_sqs
}

# 로그 그룹 소유 cloudwatch→lambda 이관 — 물리 그룹 동일, state 주소만 이동(재생성 없음)
moved {
  from = module.cloudwatch.aws_cloudwatch_log_group.lambda["cc-dev-authorizer"]
  to   = module.async.module.lambda.aws_cloudwatch_log_group.this["authorizer"]
}
moved {
  from = module.cloudwatch.aws_cloudwatch_log_group.lambda["cc-dev-ticketing"]
  to   = module.async.module.lambda.aws_cloudwatch_log_group.this["ticketing"]
}
moved {
  from = module.cloudwatch.aws_cloudwatch_log_group.lambda["cc-dev-persistence"]
  to   = module.async.module.lambda.aws_cloudwatch_log_group.this["persistence"]
}

# API Gateway — 백엔드(EKS NLB ↔ test-EC2)는 var.api_backend 로 선택, queue 는 ticketing 람다
module "apigateway" {
  source       = "../../modules/apigateway"
  project_name = var.project_name
  environment  = var.environment

  # 백엔드 선택 — eks(NLB VPC Link) | test_ec2(단일 nginx 게이트웨이)
  backend          = var.api_backend
  test_backend_url = "http://${aws_instance.test_service.public_dns}:${var.test_service_port}"

  # 경로 프리픽스(/auth,/events,/reservations,/payments) → NLB 리스너 포트(VPC Link)
  # path 는 백엔드 FastAPI 라우터 prefix 와 일치(event→/events, payment→/payments)
  nlb_arn      = module.nlb.nlb_arn
  nlb_dns_name = module.nlb.nlb_dns_name
  services = {
    for k, v in module.nlb.service_targets : k => {
      listener_port = v.listener_port
      path          = { auth = "auth", event = "events", reservation = "reservations", payment = "payments" }[k]
    }
  }

  queue_lambda_invoke_arn    = module.async.invoke_arns["ticketing"]
  queue_lambda_function_name = module.async.function_names["ticketing"]

  # captcha Lambda 가 배포(lambda-modules.txt 등록)됐을 때만 라우트 생성 — 미배포 시 plan 실패 방지
  enable_captcha_route         = contains(keys(module.async.function_names), "captcha")
  captcha_lambda_invoke_arn    = lookup(module.async.invoke_arns, "captcha", "")
  captcha_lambda_function_name = lookup(module.async.function_names, "captcha", "")

  authorizer_lambda_invoke_arn    = module.async.invoke_arns["authorizer"]
  authorizer_lambda_function_name = module.async.function_names["authorizer"]

  # 커스텀 도메인 (api.<domain>) — REGIONAL + ACM(DNS 검증, 기존 존 사용)
  api_domain_name = "api.${var.domain_name}"
  route53_zone_id = var.route53_zone_id
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
    module.async.function_names["authorizer"],
    module.async.function_names["ticketing"],
    module.async.function_names["persistence"],
  ]

  # CloudFront
  cloudfront_distribution_id = module.cloudfront.cloudfront_distribution_id

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

module "nlb" {
  source = "../../modules/nlb"

  project_name = var.project_name
  environment  = var.environment
  subnet_ids   = module.network.private_subnet_ids
  vpc_id       = module.network.vpc_id
  vpc_cidr     = module.network.vpc_cidr
  target_port  = var.ticketing_http_port

  # 4서비스 외부 노출 — 포트로 분리, API GW(#136)가 경로별로 연결
  services = {
    auth        = { listener_port = 8001 }
    event       = { listener_port = 8002 }
    reservation = { listener_port = 8003 }
    payment     = { listener_port = 8004 }
  }
}

# NLB(ip 타겟) → 파드 수신 포트 — 클러스터 SG(관리형 노드그룹·파드 ENI)에 인바운드 허용
resource "aws_security_group_rule" "pods_from_nlb" {
  type                     = "ingress"
  security_group_id        = module.eks.cluster_security_group_id
  source_security_group_id = module.nlb.nlb_sg_id
  from_port                = var.ticketing_http_port
  to_port                  = var.ticketing_http_port
  protocol                 = "tcp"
  description              = "ticketing pods from NLB"
}

# metrics-server — HPA(eks_service)가 CPU/메모리 사용률로 스케일하도록 리소스 메트릭 제공
module "metrics_server" {
  source = "../../modules/metrics_server"

  # provider 는 컨트롤 플레인에만 암시 의존 → 노드그룹 준비 전 helm 배포 시 파드 Pending·타임아웃.
  # 노드 스케줄 가능해진 뒤 배포되도록 명시 의존.
  depends_on = [module.eks]
}

# AWS Load Balancer Controller — terraform 소유 NLB 타겟그룹에 파드 IP 를 등록(TargetGroupBinding)하기 위한 컨트롤러
module "aws_lb_controller" {
  source = "../../modules/aws_lb_controller"

  project_name = var.project_name
  environment  = var.environment
  cluster_name = module.eks.cluster_name
  region       = var.aws_region
  vpc_id       = module.network.vpc_id

  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_issuer_url

  # 입력은 컨트롤 플레인에만 의존 → 노드 준비 후 배포되도록 명시 의존(helm wait 타임아웃 방지)
  depends_on = [module.eks]
}

# Cluster Autoscaler — 관리형 노드그룹(system/app) ASG desired 를 자동 조정(노드 오토스케일링)
module "cluster_autoscaler" {
  source = "../../modules/cluster_autoscaler"

  project_name = var.project_name
  environment  = var.environment
  cluster_name = module.eks.cluster_name
  region       = var.aws_region

  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_issuer_url

  # 입력은 컨트롤 플레인에만 의존 → 노드 준비 후 배포되도록 명시 의존(helm wait 타임아웃 방지)
  depends_on = [module.eks]
}

module "prometheus" {
  source = "../../modules/prometheus"

  project_name = var.project_name
  environment  = var.environment

  # EKS (틀만 — 모듈 연결 후 활성화)
  eks_cluster_name = ""
}

