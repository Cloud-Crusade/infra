variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "environment" {
  description = "배포 환경"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "프로젝트 이름 (리소스 태그 및 네이밍에 사용)"
  type        = string
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
