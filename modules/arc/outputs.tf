output "resource_identifier" {
  description = "ARC가 적용된 대상 리소스의 식별자(ARN)"
  value       = aws_arczonalshift_zonal_autoshift_configuration.this.resource_arn
}

output "zonal_autoshift_status" {
  description = "현재 설정된 Zonal Autoshift 상태"
  value       = aws_arczonalshift_zonal_autoshift_configuration.this.zonal_autoshift_status
}

output "practice_run_outcome_alarms" {
  description = "Practice Run 결과 판단에 사용된 outcome alarm 목록"
  value       = var.outcome_alarms
}

output "practice_run_blocked_windows" {
  description = "Practice Run 차단 요일/시간대 설정"
  value       = var.blocked_windows
}

output "practice_run_blocked_dates" {
  description = "Practice Run 차단 날짜 설정"
  value       = var.blocked_dates
}
