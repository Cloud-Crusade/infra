
variable "PROJECT_NAME" {
  description = "프로젝트 이름 (prefix)"
  type        = string
}

variable "ENVIRONMENT" {
  description = "배포 환경 (dev 또는 prod)"
  type        = string
}

variable "OIDC_PROVIDER_ARN" {
  description = "EKS OIDC Provider ARN (EKS 모듈에서 제공 예정)"
  type        = string
  default     = ""
}

variable "OIDC_PROVIDER_URL" {
  description = "EKS OIDC Provider URL (EKS 모듈에서 제공 예정)"
  type        = string
  default     = ""
}