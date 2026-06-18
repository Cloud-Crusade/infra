variable "project_name" {
  description = "리소스 이름에 공통으로 붙는 이름"
  type        = string
}

variable "environment" {
  description = "배포 환경 (dev/prod)"
  type        = string
}

variable "proxy_sg_id" {
  description = "RDS Proxy 에 적용할 보안 그룹 ID"
  type        = string
}

variable "subnet_ids" {
  description = "Proxy 를 배치할 프라이빗 서브넷 ID 목록"
  type        = list(string)
}

variable "db_secret_arn" {
  description = "DB 자격증명이 담긴 Secrets Manager 시크릿 ARN (username/password)"
  type        = string
}

variable "core_db_identifier" {
  description = "Core(Primary) RDS 인스턴스 identifier"
  type        = string
}

variable "reservation_db_identifier" {
  description = "Reservation RDS 인스턴스 identifier"
  type        = string
}
