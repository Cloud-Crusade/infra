variable "domain_name" {
  description = "인증서 주 도메인 (예: www.einsof.app)"
  type        = string
}

variable "subject_alternative_names" {
  description = "추가 도메인(SAN) 목록"
  type        = list(string)
  default     = []
}

variable "route53_zone_id" {
  description = "DNS 검증 레코드를 생성할 기존 Route53 호스팅 영역 ID"
  type        = string
}
