module "vpc" {
  source = "./vpc"

  project_name                   = var.project_name
  environment                    = var.environment
  vpc_cidr                       = var.vpc_cidr
  public_subnet_cidrs            = var.public_subnet_cidrs
  private_subnet_cidrs           = var.private_subnet_cidrs
  availability_zones             = var.availability_zones
  enable_nat_gateway             = var.enable_nat_gateway
  enable_secretsmanager_endpoint = var.enable_secretsmanager_endpoint
}
