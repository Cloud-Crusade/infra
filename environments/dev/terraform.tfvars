aws_region   = "ap-northeast-2"
environment  = "dev"
project_name = "cc"

vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
availability_zones   = ["ap-northeast-2a", "ap-northeast-2c"]

bastion_ami           = "ami-0a10b2721688ce9d2" # KT Cloud AMI ID
bastion_instance_type = "t3.micro"
bastion_key_name      = "bastion-key"

allowed_ssh_cidrs = ["0.0.0.0/0"]

# ============================================================
# EKS
# ============================================================
enable_nat_gateway = true # 노드 그룹이 ECR/API 서버에 접근하려면 NAT Gateway 필요

eks_cluster_version = "1.31"

eks_endpoint_public_access       = true
eks_endpoint_private_access      = true
eks_endpoint_public_access_cidrs = ["0.0.0.0/0"]

eks_enabled_log_types = ["api", "audit", "authenticator"]

# system 노드 그룹 (dev: 최소 사양)
eks_system_ng_instance_types = ["t3.medium"]
eks_system_ng_capacity_type  = "ON_DEMAND"
eks_system_ng_desired_size   = 1
eks_system_ng_min_size       = 1
eks_system_ng_max_size       = 2

# app 노드 그룹 (dev: SPOT 활용으로 비용 절감 고려)
eks_app_ng_instance_types = ["t3.medium"]
eks_app_ng_capacity_type  = "ON_DEMAND" # TODO: dev는 SPOT 변경 고려
eks_app_ng_desired_size   = 1
eks_app_ng_min_size       = 1
eks_app_ng_max_size       = 3

# TODO: 클러스터 접근이 필요한 IAM Role/User 추가
eks_access_entries = []
oidc_provider_arn  = ""
oidc_provider_url  = ""

db_username = "ccadmin"
# db_password 는 민감값 → tfvars 평문 금지.
# CI: GitHub Secret 이름을 DB_PASSWORD 로 (컨버터가 TF_VAR_ 접두사 + 소문자화 → TF_VAR_db_password)
# 로컬: export TF_VAR_db_password=...

s3_bucket_name                 = "einsof-service-625368338405-ap-northeast-2-an"
s3_bucket_regional_domain_name = "einsof-service-625368338405-ap-northeast-2-an.s3.ap-northeast-2.amazonaws.com"
