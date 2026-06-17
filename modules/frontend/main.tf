# www 커스텀 도메인용 ACM 인증서 — CloudFront 는 us-east-1 인증서만 허용
module "acm_www" {
  source = "./acm"
  providers = {
    aws = aws.us_east_1
  }

  domain_name     = "www.${var.domain_name}"
  route53_zone_id = var.route53_zone_id
}

# 클라이언트 정적 호스팅 — web + JWT 공개키가 같은 public 버킷, CloudFront 로 접근 비용 절감
module "cloudfront" {
  source       = "./cloudfront"
  project_name = var.project_name
  environment  = var.environment

  s3_bucket_name                 = var.public_bucket
  s3_bucket_regional_domain_name = var.public_bucket_domain_name

  aliases             = ["www.${var.domain_name}"]
  acm_certificate_arn = module.acm_www.certificate_arn
}
