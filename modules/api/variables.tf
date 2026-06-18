# ================== 공통 ==================
variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

# ================== nlb ==================
variable "subnet_ids" {
  type = list(string)
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "ticketing_http_port" {
  type = number
}

# ================== apigateway ==================
variable "api_backend" {
  description = "백엔드: eks | test_ec2"
  type        = string
}

variable "test_backend_url" {
  description = "test_ec2 백엔드 base URL (ops 의 test_service nginx 게이트웨이)"
  type        = string
}

# async 레이어 Lambda 출력(맵) — 라우트/authorizer 배선
variable "lambda_invoke_arns" {
  type = map(string)
}

variable "lambda_function_names" {
  type = map(string)
}

# ================== route53 (도메인 — apigateway/route53 공용) ==================
variable "domain_name" {
  type = string
}

variable "route53_zone_id" {
  type = string
}

# www 레코드 대상 — frontend(cloudfront)
variable "cloudfront_domain_name" {
  type = string
}

variable "cloudfront_zone_id" {
  type = string
}

variable "enable_az_failover" {
  description = "AZ Failover 모드 — NLB zonal shift(on)/cross-zone(off) 전환"
  type        = bool
  default     = false
}

variable "enable_cloudwatch" {
  description = "CloudWatch 사용 여부 — APIGW 액세스 로그 그룹/스테이지 로깅 on/off"
  type        = bool
  default     = true
}
