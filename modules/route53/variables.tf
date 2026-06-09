variable "domain_name" {
  type        = string
  description = "기본 도메인 이름 (예: einsof.app)"
}

variable "route53_zone_id" {
  type        = string
  description = "Route 53 호스팅 영역 ID"
}

variable "alb_dns_name" {
  type        = string
  description = "연결할 ALB의 DNS Name"
}

variable "alb_zone_id" {
  type        = string
  description = "ALB가 생성된 리전의 Zone ID (참고: 서울 리전 고정값 Z3F1SLL3L0ST3L)"

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