variable "project_name" {
  description = "프로젝트 이름 (prefix)"
  type        = string
}

variable "environment" {
  description = "배포 환경 (stage 이름)"
  type        = string
}

# MSA 백엔드는 internal NLB 를 VPC Link 로 사설 연결(REST API VPC Link 는 NLB 만 지원)
variable "nlb_arn" {
  description = "VPC Link 대상 internal NLB ARN"
  type        = string
}

variable "nlb_dns_name" {
  description = "NLB DNS 이름 (통합 uri 호스트)"
  type        = string
}

# 서비스명 → { NLB 리스너 포트, URL 경로 }. path 는 백엔드 FastAPI 라우터 prefix 와 일치해야 함
# (event→/events, payment→/payments). HTTP_PROXY 가 프리픽스를 포함해 그대로 전달.
variable "services" {
  description = "외부 노출 서비스 → { listener_port, path } (auth|event|reservation|payment)"
  type = map(object({
    listener_port = number
    path          = string
  }))
}

variable "queue_lambda_invoke_arn" {
  description = "queue Lambda 의 invoke ARN (모듈 외부에서 생성)"
  type        = string
}

variable "queue_lambda_function_name" {
  description = "queue Lambda 함수 이름 (invoke 권한 부여용)"
  type        = string
}

variable "enable_captcha_route" {
  description = "captcha Lambda 배포(등록) 여부 — true 일 때만 /captcha/challenge 라우트·권한 생성"
  type        = bool
  default     = false
}

variable "captcha_lambda_invoke_arn" {
  description = "captcha Lambda 의 invoke ARN (모듈 외부에서 생성)"
  type        = string
  default     = ""
}

variable "captcha_lambda_function_name" {
  description = "captcha Lambda 함수 이름 (invoke 권한 부여용)"
  type        = string
  default     = ""
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
