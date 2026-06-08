# ===== SNS =====

output "sns_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarms"
  value       = aws_sns_topic.alarm.arn
}

# ===== RDS =====

output "rds_cpu_alarm_arns" {
  description = "RDS CPU utilization alarm ARNs"
  value       = { for k, v in aws_cloudwatch_metric_alarm.rds_cpu : k => v.arn }
}

output "rds_connections_alarm_arns" {
  description = "RDS database connections alarm ARNs"
  value       = { for k, v in aws_cloudwatch_metric_alarm.rds_connections : k => v.arn }
}

output "rds_storage_alarm_arns" {
  description = "RDS free storage space alarm ARNs"
  value       = { for k, v in aws_cloudwatch_metric_alarm.rds_storage : k => v.arn }
}

# ===== Lambda =====

output "lambda_log_group_names" {
  description = "Lambda log group names"
  value       = { for k, v in aws_cloudwatch_log_group.lambda : k => v.name }
}

output "lambda_error_alarm_arns" {
  description = "Lambda error alarm ARNs"
  value       = { for k, v in aws_cloudwatch_metric_alarm.lambda_errors : k => v.arn }
}

output "lambda_duration_alarm_arns" {
  description = "Lambda duration alarm ARNs"
  value       = { for k, v in aws_cloudwatch_metric_alarm.lambda_duration : k => v.arn }
}

# ===== CloudFront =====

output "cloudfront_5xx_alarm_arn" {
  description = "CloudFront 5xx error rate alarm ARN"
  value       = length(aws_cloudwatch_metric_alarm.cloudfront_5xx) > 0 ? aws_cloudwatch_metric_alarm.cloudfront_5xx[0].arn : ""
}

output "cloudfront_4xx_alarm_arn" {
  description = "CloudFront 4xx error rate alarm ARN"
  value       = length(aws_cloudwatch_metric_alarm.cloudfront_4xx) > 0 ? aws_cloudwatch_metric_alarm.cloudfront_4xx[0].arn : ""
}

# ===== ElastiCache (틀만 — 모듈 연결 후 활성화) =====

output "elasticache_cpu_alarm_arns" {
  description = "ElastiCache CPU utilization alarm ARNs (activate after module connection)"
  value       = { for k, v in aws_cloudwatch_metric_alarm.elasticache_cpu : k => v.arn }
}

output "elasticache_memory_alarm_arns" {
  description = "ElastiCache memory usage alarm ARNs (activate after module connection)"
  value       = { for k, v in aws_cloudwatch_metric_alarm.elasticache_memory : k => v.arn }
}

# ===== SQS (틀만 — 모듈 연결 후 활성화) =====

output "sqs_depth_alarm_arns" {
  description = "SQS queue depth alarm ARNs (activate after module connection)"
  value       = { for k, v in aws_cloudwatch_metric_alarm.sqs_depth : k => v.arn }
}

output "sqs_age_alarm_arns" {
  description = "SQS oldest message age alarm ARNs (activate after module connection)"
  value       = { for k, v in aws_cloudwatch_metric_alarm.sqs_age : k => v.arn }
}

# ===== EKS (틀만 — 모듈 연결 후 활성화) =====

output "eks_node_cpu_alarm_arn" {
  description = "EKS node CPU utilization alarm ARN (activate after module connection)"
  value       = length(aws_cloudwatch_metric_alarm.eks_node_cpu) > 0 ? aws_cloudwatch_metric_alarm.eks_node_cpu[0].arn : ""
}

output "eks_node_memory_alarm_arn" {
  description = "EKS node memory utilization alarm ARN (activate after module connection)"
  value       = length(aws_cloudwatch_metric_alarm.eks_node_memory) > 0 ? aws_cloudwatch_metric_alarm.eks_node_memory[0].arn : ""
}
