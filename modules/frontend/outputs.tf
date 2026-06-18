# ================== cloudfront ==================
output "cloudfront_domain_name" {
  value = module.cloudfront.cloudfront_domain_name
}

output "cloudfront_distribution_id" {
  value = module.cloudfront.cloudfront_distribution_id
}
