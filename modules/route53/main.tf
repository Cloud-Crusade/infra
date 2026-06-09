
# einsof.app (Root 도메인) -> CloudFront 매핑
resource "aws_route53_record" "root" {
  zone_id = var.route53_zone_id
  name    = var.domain_name # 👈 "www." 없이 변수명만 지정하면 루트 도메인이 됩니다.
  type    = "A"

  alias {
    name                   = var.cloudfront_domain_name
    zone_id                = var.cloudfront_zone_id
    evaluate_target_health = false
  }
}

# api.einsof.app -> ALB 매핑
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

# www.einsof.app -> CloudFront 매핑
resource "aws_route53_record" "www" {
  zone_id = var.route53_zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.cloudfront_domain_name
    zone_id                = var.cloudfront_zone_id 
    evaluate_target_health = false
  }
}