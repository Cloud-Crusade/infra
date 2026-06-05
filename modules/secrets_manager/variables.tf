variable "project_name" {
  description = "프로젝트 이름 (prefix)"
  type        = string
}

variable "environment" {
  description = "배포 환경 (dev 또는 prod)"
  type        = string
}

variable "private_key_value" {
  description = "JWT 서명용 Private Key 값"
  type        = string
  sensitive   = true
  default     = ""
}

variable "rds_username" {
  description = "RDS 접속 username"
  type        = string
  sensitive   = true
  default     = ""
}

variable "rds_password" {
  description = "RDS 접속 password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "rds_writer_endpoint" {
  description = "RDS Writer 엔드포인트 주소"
  type        = string
  default     = ""
}
