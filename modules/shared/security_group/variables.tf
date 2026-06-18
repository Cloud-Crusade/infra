variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "environment" {
  description = "배포 환경"
  type        = string
}

variable "vpc_id" {
  description = "vpc id"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR (RDS egress 를 VPC 내부로 한정)"
  type        = string
}

variable "private_subnet_cidrs" {
  description = "EKS 파드(private subnet)에서 RDS/Cache 접근 허용용 CIDR 목록"
  type        = list(string)
}

variable "allowed_ssh_cidrs" {
  description = "Bastion host SSH 접근 허용 IP 목록"
  type        = list(string)
}