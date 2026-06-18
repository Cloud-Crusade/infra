# ================== nlb ==================
output "nlb_sg_id" {
  value = module.nlb.nlb_sg_id
}

output "service_targets" {
  value = module.nlb.service_targets
}

# ARC zonal autoshift 대상(shared/arc 소비) — 전체 NLB ARN
output "nlb_arn" {
  value = module.nlb.nlb_arn
}

# ARC zonal-shift outcome 알람 dimension(shared/cloudwatch 소비)
output "lb_arn_suffix" {
  value = module.nlb.lb_arn_suffix
}

output "target_group_arn_suffixes" {
  value = module.nlb.target_group_arn_suffixes
}

# ================== route53 ==================
output "www_record_fqdn" {
  value = module.route53.www_record_fqdn
}

output "api_record_fqdn" {
  value = module.route53.api_record_fqdn
}
