variable "PROJECT_NAME" {
  description = "프로젝트 이름"
  type        = string
}

variable "ENVIRONMENT" {
  description = "배포 환경"
  type        = string
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
  description = "NAT Gateway 생성 여부"
  type        = bool
  default     = true
}