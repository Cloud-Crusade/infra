variable "PROJECT_NAME" {
  description = "프로젝트 이름"
  type        = string
}

variable "ENVIRONMENT" {
  description = "배포 환경"
  type        = string
}

variable "VPC_ID" {
  description = "vpc id"
  type        = string
}

variable "ALLOWED_SSH_CIDRS" {
  description = "Bastion host SSH 접근 허용 IP 목록"
  type        = list(string)
}