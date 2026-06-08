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
}

module "security_groups" {
  source = "../../modules/security_group"

  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
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
  node_role_arn    = module.iam.node_role_arn
  vpc_cni_role_arn = module.iam.vpc_cni_role_arn
  ebs_csi_role_arn = module.iam.ebs_csi_role_arn

  access_entries = var.eks_access_entries
}

/** RDS / ElastiCache 추가 후 
# SVC
resource "kubernetes_service_v1" "rds" {
  metadata {
    name = "rds-svc"
    namespace = "default"
  }

  spec {
    type = "ExternalName"
    external_name = var.rds_endpoint
  }

  depends_on = [module.rds]
}

resource "kubernetes_service_v1" "elasticache" {
  metadata {
    name = "elasticache-svc"
    namespace = "default"
  }

  spec {
    type = "ExternalName"
    external_name = var.elasticache_endpoint
  }

  depends_on = [module.elasticache]
}
*/