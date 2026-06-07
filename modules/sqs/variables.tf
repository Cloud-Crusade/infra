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
}

variable "message_retention_seconds" {
  description = "메시지 보관 기간(초)"
  type        = number
  default     = 345600 # 4일
}

variable "max_receive_count" {
  description = "DLQ 로 이동하기 전 최대 수신 횟수"
  type        = number
  default     = 5
}

variable "dlq_message_retention_seconds" {
  description = "DLQ 메시지 보관 기간(초)"
  type        = number
  default     = 1209600 # 14일
}
