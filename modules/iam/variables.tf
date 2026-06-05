
variable "project_name" {
  description = "프로젝트 이름 (prefix)"
  type        = string
}

variable "environment" {
  description = "배포 환경 (dev 또는 prod)"
  type        = string
}

variable "oidc_provider_arn" {
  description = "EKS OIDC Provider ARN (EKS 모듈에서 제공 예정)"
  type        = string
  default     = ""
}

variable "oidc_provider_url" {
  description = "EKS OIDC Provider URL (EKS 모듈에서 제공 예정)"
  type        = string
  default     = ""
}