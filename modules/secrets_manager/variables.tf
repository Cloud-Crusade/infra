variable "project_name" {
  description = "프로젝트 이름 (prefix)"
  type        = string
}

variable "environment" {
  description = "배포 환경 (dev 또는 prod)"
  type        = string
}

variable "authorization_secret_value" {
  description = "authorization JWT 서명용 대칭 시크릿 (HS256)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "reservation_private_key_value" {
  description = "reservation JWT 서명용 Private Key (PEM)"
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

variable "core_writer_endpoint" {
  description = "메인(core) RDS Writer 엔드포인트 주소"
  type        = string
  default     = ""
}

variable "reservation_writer_endpoint" {
  description = "예약(reservation) RDS Writer 엔드포인트 주소"
  type        = string
  default     = ""
}
