# ================== nlb ==================
output "nlb_sg_id" {
  value = module.nlb.nlb_sg_id
}

output "service_targets" {
  value = module.nlb.service_targets
}

# ================== route53 ==================
output "www_record_fqdn" {
  value = module.route53.www_record_fqdn
}

output "api_record_fqdn" {
  value = module.route53.api_record_fqdn
}
