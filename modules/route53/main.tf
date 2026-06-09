
resource "aws_route53_record" "cloudfront_domains" {
  for_each = toset([
    var.domain_name,          
    "www.${var.domain_name}"  
  ])

  zone_id = var.route53_zone_id
  name    = each.value
  type    = "A"

  alias {
    name                   = var.cloudfront_domain_name
    zone_id                = var.cloudfront_zone_id 
    evaluate_target_health = false
  }
}

# 2. api.einsof.app -> ALB 매핑
resource "aws_route53_record" "api" {
  zone_id = var.route53_zone_id
  name    = "api.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}