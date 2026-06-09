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
