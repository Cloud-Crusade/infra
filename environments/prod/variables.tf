variable "AWS_REGION" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "ENVIRONMENT" {
  description = "배포 환경 (dev | prod)"
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "prod"], var.ENVIRONMENT)
    error_message = "environment 값은 'dev' 또는 'prod' 이어야 합니다."
  }
}

variable "PROJECT_NAME" {
  description = "프로젝트 이름 (리소스 태그 및 네이밍에 사용)"
  type        = string
  default     = "ktcloud-cc-infra"
}

variable "VPC_CIDR" {
  description = "VPC CIDR 블록"
  type        = string
}

variable "PUBLIC_SUBNET_CIDRS" {
  description = "퍼블릭 서브넷 CIDR 목록"
  type        = list(string)
}

variable "PRIVATE_SUBNET_CIDRS" {
  description = "프라이빗 서브넷 CIDR 목록"
  type        = list(string)
}

variable "AVAILABILITY_ZONES" {
  description = "사용할 가용 영역 목록"
  type        = list(string)
}

variable "OIDC_PROVIDER_ARN" {
  description = "EKS OIDC Provider ARN"
  type        = string
  default     = ""
}

variable "OIDC_PROVIDER_URL" {
  description = "EKS OIDC Provider URL"
  type        = string
  default     = ""
}