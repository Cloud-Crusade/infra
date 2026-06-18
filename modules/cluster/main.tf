module "eks" {
  source = "./eks"

  project_name = var.project_name
  environment  = var.environment
  subnet_ids   = var.subnet_ids

  additional_security_group_ids = [var.eks_sg_id]

  cluster_version                      = var.cluster_version
  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_endpoint_private_access      = var.cluster_endpoint_private_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  cluster_enabled_log_types            = var.cluster_enabled_log_types

  system_ng_instance_types = var.system_ng_instance_types
  system_ng_capacity_type  = var.system_ng_capacity_type
  system_ng_desired_size   = var.system_ng_desired_size
  system_ng_min_size       = var.system_ng_min_size
  system_ng_max_size       = var.system_ng_max_size

  app_ng_instance_types = var.app_ng_instance_types
  app_ng_capacity_type  = var.app_ng_capacity_type
  app_ng_desired_size   = var.app_ng_desired_size
  app_ng_min_size       = var.app_ng_min_size
  app_ng_max_size       = var.app_ng_max_size

  access_entries = var.access_entries
}

# ticketing 인클러스터 워크로드 — eks(클러스터) 와 분리. OIDC 는 eks 출력에서 주입(reservation IRSA)
module "workloads" {
  source = "./workloads"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer_url   = module.eks.oidc_issuer_url

  domain_name         = var.domain_name
  captcha_enabled     = var.captcha_enabled
  ticketing_image_tag = var.ticketing_image_tag
  ecr_namespace       = var.ecr_namespace
  ecr_registry        = var.ecr_registry

  rds_core_writer_endpoint        = var.rds_core_writer_endpoint
  rds_core_reader_endpoint        = var.rds_core_reader_endpoint
  rds_reservation_writer_endpoint = var.rds_reservation_writer_endpoint
  rds_reservation_reader_endpoint = var.rds_reservation_reader_endpoint
  redis_main_endpoint             = var.redis_main_endpoint

  sqs_queue_url = var.sqs_queue_url
  sqs_queue_arn = var.sqs_queue_arn

  jwt_secret          = var.jwt_secret
  captcha_hmac_secret = var.captcha_hmac_secret

  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password

  # 노드그룹 준비 후 워크로드 스케줄(부트스트랩·마이그레이션 Job)
  depends_on = [module.eks]
}

# metrics-server — HPA 메트릭. 노드 준비 후 배포(helm wait 타임아웃 방지)
module "metrics_server" {
  source     = "./metrics_server"
  depends_on = [module.eks]
}

# AWS Load Balancer Controller — NLB 타겟그룹에 파드 IP 등록(TargetGroupBinding). OIDC 는 인-레이어 참조
module "aws_lb_controller" {
  source = "./aws_lb_controller"

  project_name      = var.project_name
  environment       = var.environment
  cluster_name      = module.eks.cluster_name
  region            = var.aws_region
  vpc_id            = var.vpc_id
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_issuer_url

  depends_on = [module.eks]
}

# Cluster Autoscaler — 노드그룹 ASG 오토스케일링
module "cluster_autoscaler" {
  source = "./cluster_autoscaler"

  project_name      = var.project_name
  environment       = var.environment
  cluster_name      = module.eks.cluster_name
  region            = var.aws_region
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_issuer_url

  depends_on = [module.eks]
}

module "prometheus" {
  source       = "./prometheus"
  project_name = var.project_name
  environment  = var.environment

  # 게이트 해제 — Prometheus(+node_exporter DaemonSet) 각 노드 자동 배포
  eks_cluster_name = module.eks.cluster_name
}
