variable "project_name" {
  description = "프로젝트 이름 (prefix)"
  type        = string
}

variable "environment" {
  description = "배포 환경"
  type        = string
}

variable "app_backend_url" {
  description = "기본 백엔드(EKS/app) base URL — Authorization 은 EKS 가 판별"
  type        = string
}

variable "reservation_backend_url" {
  description = "예약 경로 백엔드 base URL (테스트용 EC2)"
  type        = string
}
