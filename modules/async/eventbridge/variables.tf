variable "project_name" {
  type        = string
  description = "프로젝트 이름"
}

variable "environment" {
  type        = string
  description = "배포 환경"
}

variable "target_lambda_arn" {
  description = "EventBridge Target Lambda ARN"
  type        = string
}

variable "target_lambda_function_name" {
  description = "EventBridge Target Lambda Function Name"
  type        = string
}

variable "apigw_429_threshold" {
  type        = number
  description = "1분 내 API Gateway 429 응답 수 임계값 — 초과 시 bot_block Lambda 트리거"
  default     = 20
}