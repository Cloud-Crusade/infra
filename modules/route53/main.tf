# 1. www 도메인  -> CloudFront 매핑
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

# 2. api 도메인 -> 트래픽 라우팅 대상(ALB/NLB 등) 매핑
resource "aws_route53_record" "api" {
  zone_id = var.route53_zone_id
  name    = "api.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.api_target_dns_name
    zone_id                = var.api_target_zone_id
    evaluate_target_health = true
  }
} 