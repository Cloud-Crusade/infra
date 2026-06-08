variable "project_name" {
  description = "프로젝트 이름 (prefix)"
  type        = string
}

variable "environment" {
  description = "배포 환경"
  type        = string
}

variable "name" {
  description = "큐 용도 이름 (예: reservation). 실제 큐명은 <project>-<env>-<name>.fifo"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+$", var.name))
    error_message = "name 은 영숫자/하이픈/언더스코어만 허용됩니다 (.fifo 는 모듈이 자동 부여)."
  }
}

variable "content_based_deduplication" {
  description = "메시지 본문 기반 중복 제거. false 면 producer 가 MessageDeduplicationId 를 지정해야 함"
  type        = bool
  default     = true
}

variable "visibility_timeout_seconds" {
  description = "가시성 타임아웃(초) — 소비 람다 timeout 이상 권장"
  type        = number
  default     = 30

  validation {
    condition     = var.visibility_timeout_seconds >= 0 && var.visibility_timeout_seconds <= 43200 && floor(var.visibility_timeout_seconds) == var.visibility_timeout_seconds
    error_message = "visibility_timeout_seconds 는 0~43200 사이 정수여야 합니다."
  }
}

variable "message_retention_seconds" {
  description = "메시지 보관 기간(초)"
  type        = number
  default     = 345600 # 4일

  validation {
    condition     = var.message_retention_seconds >= 60 && var.message_retention_seconds <= 1209600 && floor(var.message_retention_seconds) == var.message_retention_seconds
    error_message = "message_retention_seconds 는 60~1209600 사이 정수여야 합니다."
  }
}

variable "max_receive_count" {
  description = "DLQ 로 이동하기 전 최대 수신 횟수"
  type        = number
  default     = 5

  validation {
    condition     = var.max_receive_count >= 1 && var.max_receive_count <= 1000 && floor(var.max_receive_count) == var.max_receive_count
    error_message = "max_receive_count 는 1~1000 사이 정수여야 합니다."
  }
}

variable "dlq_message_retention_seconds" {
  description = "DLQ 메시지 보관 기간(초)"
  type        = number
  default     = 1209600 # 14일

  validation {
    condition     = var.dlq_message_retention_seconds >= 60 && var.dlq_message_retention_seconds <= 1209600 && floor(var.dlq_message_retention_seconds) == var.dlq_message_retention_seconds
    error_message = "dlq_message_retention_seconds 는 60~1209600 사이 정수여야 합니다."
  }
}
