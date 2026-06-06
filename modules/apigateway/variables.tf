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

variable "authorizer_lambda_invoke_arn" {
  description = "예약 Reservation 헤더 authorizer Lambda 의 invoke ARN (모듈 외부에서 생성)"
  type        = string
}

variable "authorizer_lambda_function_name" {
  description = "예약 authorizer Lambda 함수 이름 (invoke 권한 부여용)"
  type        = string
}

variable "queue_lambda_invoke_arn" {
  description = "queue Lambda 의 invoke ARN (모듈 외부에서 생성)"
  type        = string
}

variable "queue_lambda_function_name" {
  description = "queue Lambda 함수 이름 (invoke 권한 부여용)"
  type        = string
}
