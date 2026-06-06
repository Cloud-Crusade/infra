variable "PROJECT_NAME" {
  description = "리소스 이름에 공통으로 붙는 이름"
  type        = string
}

variable "DB_NAME" {
  description = "RDS 데이터베이스 이름"
  type        = string
}

variable "DB_USERNAME" {
  description = "RDS 사용자 이름"
  type        = string
}

variable "DB_PASSWORD" {
  description = "RDS 비밀번호"
  type        = string
  sensitive   = true
}

variable "INSTANCE_CLASS" {
  description = "RDS 인스턴스 타입"
  type        = string
  default     = "db.t3.micro"
}

variable "ENGINE_VERSION" {
  description = "PostgreSQL 버전"
  type        = string
  default     = "13.18"
}

variable "ALLOCATED_STORAGE" {
  description = "RDS 스토리지 크기 (GB 단위)"
  type        = number
  default     = 20
}

variable "VPC_SECURITY_GROUP_IDS" {
  description = "RDS에 적용할 보안 그룹 ID 목록"
  type        = list(string)
}

variable "AZS" {
  description = "RDS를 배치할 가용 영역 (반드시 리스트 타입으로 입력)"
  type        = list(string)
}

variable "SUBNET_IDS" {
  description = "DB 서브넷 그룹에 포함할 서브넷 ID 목록 (프라이빗)"
  type        = list(string)
}