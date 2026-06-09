variable "project_name" {
  description = "프로젝트 이름 (prefix)"
  type        = string
}

variable "environment" {
  description = "배포 환경 (stage 이름)"
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

variable "queue_lambda_invoke_arn" {
  description = "queue Lambda 의 invoke ARN (모듈 외부에서 생성)"
  type        = string
}

variable "queue_lambda_function_name" {
  description = "queue Lambda 함수 이름 (invoke 권한 부여용)"
  type        = string
}

variable "authorizer_lambda_invoke_arn" {
  description = "예약 토큰 서명 검증 authorizer Lambda 의 invoke ARN (모듈 외부 생성)"
  type        = string
}

variable "authorizer_lambda_function_name" {
  description = "authorizer Lambda 함수 이름 (invoke 권한 부여용)"
  type        = string
}

variable "api_domain_name" {
  description = "API Gateway 커스텀 도메인 (Route53 api 레코드와 동일, 예: api.einsof.app)"
  type        = string
}

variable "route53_zone_id" {
  description = "ACM DNS 검증 레코드를 생성할 기존 Route53 호스팅 영역 ID"
  type        = string
}
