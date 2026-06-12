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

  validation {
    condition     = var.artifact_prefix == "" || (endswith(var.artifact_prefix, "/") && !startswith(var.artifact_prefix, "/"))
    error_message = "artifact_prefix 는 빈 문자열이거나 'lambda/' 처럼 끝에 '/' 가 있고 시작에 '/' 가 없어야 합니다."
  }
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

variable "vpc_modules" {
  type        = set(string)
  description = "VPC 에 연결할 모듈명 집합 (ElastiCache/RDS 등 VPC 내부 접근). 비우면 미연결"
  default     = []
}

variable "vpc_subnet_ids" {
  type        = list(string)
  description = "VPC 연결 람다의 서브넷 ID 목록 (보통 프라이빗)"
  default     = []
}

variable "vpc_security_group_ids" {
  type        = list(string)
  description = "VPC 연결 람다의 보안 그룹 ID 목록"
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
  default     = "index.lambda_handler"
}

variable "timeout" {
  type        = number
  description = "Lambda 타임아웃(초)"
  default     = 30
}

variable "layers" {
  type        = map(list(string))
  description = "모듈명 → Lambda Layer ARN 목록 (예: captcha 의 Secrets 확장 레이어). 없는 모듈은 미부착"
  default     = {}
}
