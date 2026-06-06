variable "AWS_REGION" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "ENVIRONMENT" {
  description = "배포 환경 (dev | prod)"
  type        = string
  default     = "dev"

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

variable "ENABLE_NAT_GATEWAY" {
  description = "NAT Gateway 생성 여부 (dev 환경에서는 비용 절감을 위해 기본값 false)"
  type        = bool
  default     = false
}

variable "BASTION_AMI" {
  description = "Bastion Host AMI"
  type        = string
}

variable "BASTION_INSTANCE_TYPE" {
  description = "Bastion host 인스턴스 타입"
  type        = string
  default     = "t3.micro"
}

variable "BASTION_KEY_NAME" {
  description = "Bastion Host SSH 키페어 이름"
  type        = string
}

variable "ALLOWED_SSH_CIDRS" {
  description = "Bastion host SSH 접근 허용 IP 목록"
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

variable "DB_USERNAME" {
  description = "RDS 마스터 사용자 이름"
  type        = string
}

variable "DB_PASSWORD" {
  description = "RDS 마스터 비밀번호 (평문 tfvars 금지 — TF_VAR_DB_PASSWORD 로 주입)"
  type        = string
  sensitive   = true
}