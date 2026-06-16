# ================== 공통 ==================
variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  description = "워크로드 ConfigMap(AWS_REGION) 주입용 리전"
  type        = string
}

# ================== OIDC (eks 모듈에서 주입 — reservation IRSA) ==================
variable "oidc_provider_arn" {
  type = string
}

variable "oidc_issuer_url" {
  description = "EKS OIDC Issuer URL (https:// 포함 — 내부에서 제거)"
  type        = string
}

# ================== ticketing 워크로드 ==================
variable "domain_name" {
  description = "CORS 허용 오리진(https://www.<domain>) 구성용 기본 도메인"
  type        = string
}

variable "captcha_enabled" {
  description = "캡차(ALTCHA PoW) 활성화 — 앱 CAPTCHA_ENABLED 주입"
  type        = bool
  default     = false
}

variable "ticketing_image_tag" {
  description = "워크로드 초기 이미지 태그 (이후 롤아웃은 cc/app CD 가 갱신 → image 변경은 terraform ignore)"
  type        = string
  default     = "latest"
}

variable "ecr_registry" {
  description = "ECR 레지스트리 호스트. 리포지토리(ticketing-<svc>)는 terraform 밖에서 선행 생성"
  type        = string
}

# ----- data 레이어 엔드포인트(ExternalName 타깃, host:port) -----
variable "rds_core_writer_endpoint" {
  type = string
}

variable "rds_core_reader_endpoint" {
  type = string
}

variable "rds_reservation_writer_endpoint" {
  type = string
}

variable "rds_reservation_reader_endpoint" {
  type = string
}

variable "redis_main_endpoint" {
  type = string
}

# ----- async 레이어(예약 큐) -----
variable "sqs_queue_url" {
  type = string
}

variable "sqs_queue_arn" {
  description = "reservation IRSA SendMessage 대상"
  type        = string
}

# ----- 공유 시크릿(검증측과 공유) -----
variable "jwt_secret" {
  type      = string
  sensitive = true
}

variable "captcha_hmac_secret" {
  type      = string
  sensitive = true
}

# ----- DB 마스터 크리덴셜(서비스별 롤 부트스트랩) -----
variable "db_name" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}
