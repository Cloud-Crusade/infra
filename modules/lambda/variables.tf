variable "project_name" {
  type        = string
  description = "프로젝트 이름 (prefix)"
}

variable "environment" {
  type        = string
  description = "배포 환경"
}

variable "lambda_role_arn" {
  type        = string
  description = "Lambda 함수 실행에 필요한 IAM Role ARN (모든 Lambda 공통)"
}

variable "artifact_bucket" {
  type        = string
  description = "lambda-modules.txt 와 <module>.zip 이 있는 S3 버킷"
}

variable "artifact_prefix" {
  type        = string
  description = "아티팩트 S3 prefix (예: lambda/)"
  default     = "lambda/"
}

variable "lambda_env" {
  type        = map(map(string))
  description = "모듈명 → 환경변수 맵. 항목이 없는 모듈은 environment 블록을 만들지 않음. 시크릿은 값이 아닌 ARN 주입 권장."
  default     = {}
}

variable "function_url_modules" {
  type        = set(string)
  description = "Function URL 을 생성할 모듈명 집합 (기본: 없음)"
  default     = []
}

variable "runtime" {
  type        = string
  description = "Lambda 런타임"
  default     = "python3.11"
}

variable "handler" {
  type        = string
  description = "Lambda 핸들러"
  default     = "index.handler"
}

variable "timeout" {
  type        = number
  description = "Lambda 타임아웃(초)"
  default     = 30
}
