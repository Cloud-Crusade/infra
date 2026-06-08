aws_region   = "ap-northeast-2"
environment  = "prod"
project_name = "cc"

vpc_cidr             = "10.10.0.0/16"
public_subnet_cidrs  = ["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"]
private_subnet_cidrs = ["10.10.11.0/24", "10.10.12.0/24", "10.10.13.0/24"]
availability_zones   = ["ap-northeast-2a", "ap-northeast-2b", "ap-northeast-2c"]

# ============================================================
# EKS
# ============================================================
eks_cluster_version = "1.31"

# prod: 퍼블릭 엔드포인트 비활성화 권장 (bastion / VPN 통해서만 접근)
eks_endpoint_public_access       = false
eks_endpoint_private_access      = true
eks_endpoint_public_access_cidrs = [] # public access 비활성화 시 무의미

eks_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

# system 노드 그룹 (prod: 고가용성 — 2개 이상 유지)
eks_system_ng_instance_types = ["t3.large"]
eks_system_ng_capacity_type  = "ON_DEMAND"
eks_system_ng_desired_size   = 2
eks_system_ng_min_size       = 2
eks_system_ng_max_size       = 3

# app 노드 그룹
eks_app_ng_instance_types = ["t3.large"]
eks_app_ng_capacity_type  = "ON_DEMAND"
eks_app_ng_desired_size   = 2
eks_app_ng_min_size       = 2
eks_app_ng_max_size       = 6

# TODO: prod 클러스터 접근 IAM Role 추가
eks_access_entries = []
