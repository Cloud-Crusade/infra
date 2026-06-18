variable "project_name" {
  description = "리소스 이름에 공통으로 붙는 이름"
  type        = string
}

variable "environment" {
  description = "배포 환경 (리소스 네이밍에 포함 — dev/prod 충돌 방지)"
  type        = string
}

variable "db_name" {
  description = "RDS 데이터베이스 이름"
  type        = string
}

variable "db_username" {
  description = "RDS 사용자 이름"
  type        = string
}

variable "db_password" {
  description = "RDS 비밀번호"
  type        = string
  sensitive   = true
}

variable "instance_class" {
  description = "RDS 인스턴스 타입"
  type        = string
  default     = "db.t3.micro"
}

variable "engine_version" {
  description = "PostgreSQL 버전"
  type        = string
  default     = "13.23"
}

variable "allocated_storage" {
  description = "RDS 스토리지 크기 (GB 단위)"
  type        = number
  default     = 20
}

variable "vpc_security_group_ids" {
  description = "RDS에 적용할 보안 그룹 ID 목록"
  type        = list(string)
}

variable "azs" {
  description = "RDS를 배치할 가용 영역 (반드시 리스트 타입으로 입력)"
  type        = list(string)
}

variable "subnet_ids" {
  description = "DB 서브넷 그룹에 포함할 서브넷 ID 목록 (프라이빗)"
  type        = list(string)
}

variable "multi_az" {
  description = "writer Multi-AZ 배치 여부. true 면 availability_zone 명시 불가(AWS 가 대기 AZ 자동 선택)"
  type        = bool
  default     = false
}