variable "project_name" {
  description = "프로젝트 이름 (prefix)"
  type        = string
}

variable "environment" {
  description = "배포 환경 (dev 또는 prod)"
  type        = string
}

variable "s3_bucket_name" {
  description = "CloudFront와 연결할 S3 버킷 이름"
  type        = string
}

variable "s3_bucket_regional_domain_name" {
  description = "S3 버킷 리전 도메인 이름"
  type        = string
}

variable "aliases" {
  description = "CloudFront 대체 도메인(CNAME) 목록 (예: [\"www.einsof.app\"]). acm_certificate_arn 과 함께 사용"
  type        = list(string)
  default     = []
}

variable "acm_certificate_arn" {
  description = "커스텀 도메인용 ACM 인증서 ARN (us-east-1). 비우면 CloudFront 기본 인증서 사용"
  type        = string
  default     = ""
}
