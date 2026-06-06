terraform {
  required_version = ">= 1.15.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.AWS_REGION

  default_tags {
    tags = {
      Project     = var.PROJECT_NAME
      Environment = var.ENVIRONMENT
      ManagedBy   = "Terraform"
    }
  }
}

module "vpc" {
  source = "../../modules/vpc"

  PROJECT_NAME         = var.PROJECT_NAME
  ENVIRONMENT          = var.ENVIRONMENT
  VPC_CIDR             = var.VPC_CIDR
  PUBLIC_SUBNET_CIDRS  = var.PUBLIC_SUBNET_CIDRS
  PRIVATE_SUBNET_CIDRS = var.PRIVATE_SUBNET_CIDRS
  AVAILABILITY_ZONES   = var.AVAILABILITY_ZONES
  ENABLE_NAT_GATEWAY   = var.ENABLE_NAT_GATEWAY
}

module "security_groups" {
  source = "../../modules/security_group"

  PROJECT_NAME      = var.PROJECT_NAME
  ENVIRONMENT       = var.ENVIRONMENT
  VPC_ID            = module.vpc.vpc_id
  ALLOWED_SSH_CIDRS = var.ALLOWED_SSH_CIDRS
}

module "iam" {
  source = "../../modules/iam"

  PROJECT_NAME      = var.PROJECT_NAME
  ENVIRONMENT       = var.ENVIRONMENT
  OIDC_PROVIDER_ARN = var.OIDC_PROVIDER_ARN
  OIDC_PROVIDER_URL = var.OIDC_PROVIDER_URL
}

module "rds" {
  source = "../../modules/rds"

  PROJECT_NAME           = var.PROJECT_NAME
  DB_NAME                = "ccdb"
  DB_USERNAME            = var.DB_USERNAME
  DB_PASSWORD            = var.DB_PASSWORD
  VPC_SECURITY_GROUP_IDS = [module.security_groups.rds_sg_id]
  AZS                    = var.AVAILABILITY_ZONES
  SUBNET_IDS             = module.vpc.private_subnet_ids
}
