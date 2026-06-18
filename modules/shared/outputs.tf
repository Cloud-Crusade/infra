output "sns_topic_arn" {
  value = one(module.cloudwatch[*].sns_topic_arn)
}

output "dashboard_name" {
  value = one(module.cloudwatch[*].dashboard_name)
}

# ================== SG id (도메인 레이어가 소비) ==================
output "eks_sg_id" {
  value = module.security_group.eks_sg_id
}

output "rds_sg_id" {
  value = module.security_group.rds_sg_id
}

output "rds_proxy_sg_id" {
  value = module.security_group.rds_proxy_sg_id
}

output "cache_sg_id" {
  value = module.security_group.cache_sg_id
}

output "lambda_sg_id" {
  value = module.security_group.lambda_sg_id
}

output "bastion_sg_id" {
  value = module.security_group.bastion_sg_id
}
