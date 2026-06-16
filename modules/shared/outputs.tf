output "sns_topic_arn" {
  value = module.cloudwatch.sns_topic_arn
}

output "dashboard_name" {
  value = module.cloudwatch.dashboard_name
}
