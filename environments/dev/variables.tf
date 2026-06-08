variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "environment" {
  description = "배포 환경 (dev | prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment 값은 'dev' 또는 'prod' 이어야 합니다."
  }
}

variable "project_name" {
  description = "프로젝트 이름 (리소스 태그 및 네이밍에 사용)"
  type        = string
  default     = "ktcloud-cc-infra"
}

variable "vpc_cidr" {
  description = "VPC CIDR 블록"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "퍼블릭 서브넷 CIDR 목록"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "프라이빗 서브넷 CIDR 목록"
  type        = list(string)
}

variable "availability_zones" {
  description = "사용할 가용 영역 목록"
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "NAT Gateway 생성 여부 (dev 환경에서는 비용 절감을 위해 기본값 false)"
  type        = bool
  default     = false
}

variable "bastion_ami" {
  description = "Bastion Host AMI"
  type        = string
}

variable "bastion_instance_type" {
  description = "Bastion host 인스턴스 타입"
  type        = string
  default     = "t3.micro"
}

variable "bastion_key_name" {
  description = "Bastion Host SSH 키페어 이름"
  type        = string
}

variable "allowed_ssh_cidrs" {
  description = "Bastion host SSH 접근 허용 IP 목록"
  type        = list(string)
}

# ============================================================
# EKS
# ============================================================
variable "eks_cluster_version" {
  description = "Kubernetes 버전"
  type        = string
}

variable "eks_endpoint_public_access" {
  type    = bool
  default = true
}

variable "eks_endpoint_private_access" {
  type    = bool
  default = true
}

variable "eks_endpoint_public_access_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "eks_enabled_log_types" {
  type    = list(string)
  default = ["api", "audit", "authenticator"]
}

variable "eks_system_ng_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "eks_system_ng_capacity_type" {
  type    = string
  default = "ON_DEMAND"
}

variable "eks_system_ng_desired_size" {
  type    = number
  default = 1
}

variable "eks_system_ng_min_size" {
  type    = number
  default = 1
}

variable "eks_system_ng_max_size" {
  type    = number
  default = 2
}

variable "eks_app_ng_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "eks_app_ng_capacity_type" {
  type    = string
  default = "ON_DEMAND"
}

variable "eks_app_ng_desired_size" {
  type    = number
  default = 1
}

variable "eks_app_ng_min_size" {
  type    = number
  default = 1
}

variable "eks_app_ng_max_size" {
  type    = number
  default = 3
}

variable "eks_access_entries" {
  type = list(object({
    principal_arn     = string
    kubernetes_groups = optional(list(string), [])
    type              = optional(string, "STANDARD")
    policy_arn        = optional(string, null)
  }))
  default = []
}
