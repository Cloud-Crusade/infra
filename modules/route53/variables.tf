variable "domain_name" {
  type        = string
  description = "기본 도메인 이름 (예: einsof.app)"
}

variable "route53_zone_id" {
  type        = string
  description = "Route 53 호스팅 영역 ID"
}

variable "api_target_dns_name" {
  type        = string
  description = "api 레코드가 가리킬 트래픽 라우팅 대상(ALB 등)의 DNS Name"
}

variable "api_target_zone_id" {
  type        = string
  description = "api 라우팅 대상의 호스팅 Zone ID (예: 서울 리전 ALB 고정값 Z3F1SLL3L0ST3L)"
}

variable "cloudfront_domain_name" {
  type        = string
  description = "연결할 CloudFront의 배포 도메인 주소"
}

# ⭐️ 새로 추가된 CloudFront 고정 Zone ID 변수
variable "cloudfront_zone_id" {
  type        = string
  description = "CloudFront 고정 배포 Zone ID (참고: 전 세계 고정 값Z2FDTNDATAQYW2 )"

}