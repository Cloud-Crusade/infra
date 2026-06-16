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