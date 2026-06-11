variable "lb_arn" {
  description = "ALB/NLB ARN"
  type = string
}

variable "zonal_autoshift_status" {
  description = "Zonal Autoshift 활성화 여부 (ENABLED 또는 DISABLED)"
  type        = string
  default     = "DISABLED"

  validation {
    condition     = contains(["ENABLED", "DISABLED"], var.zonal_autoshift_status)
    error_message = "zonal_autoshift_status는 ENABLED 또는 DISABLED 값만 허용됩니다."
  }
}

variable "outcome_alarms" {
  description = "Practice Run 결과 판단에 사용할 CloudWatch 알람 목록"
  type = list(object({
    type             = string
    alarm_identifier = string
  }))

  validation {
    condition     = length(var.outcome_alarms) > 0
    error_message = "Zonal Autoshift 활성화를 위해서는 최소 1개 이상의 outcome alarm이 필요합니다."
  }
}

variable "blocked_windows" {
  description = "Practice Run 실행을 차단할 요일/시간대 목록"
  type = list(object({
    day_of_week = string
    start_time  = string
    end_time    = string
  }))
  default = []
}

variable "blocked_dates" {
  description = "Practice Run 실행을 차단할 특정 날짜 목록 (YYYY-MM-DD 형식)"
  type        = list(string)
  default     = []
}
