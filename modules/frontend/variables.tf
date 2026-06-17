# ================== 공통 ==================
variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

# ================== cloudfront / acm_www ==================
variable "domain_name" {
  type = string
}

variable "route53_zone_id" {
  type = string
}

variable "public_bucket" {
  description = "공개 S3 버킷 이름 (web 정적 + JWT 공개키)"
  type        = string
}

variable "public_bucket_domain_name" {
  description = "공개 S3 버킷 리전별 도메인 이름"
  type        = string
}
