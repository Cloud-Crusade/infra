output "event_bus_name" {
  description = "EventBridge Bus Name"
  value       = "default"
}

output "event_rule_name" {
  description = "EventBridge Rule Name"
  value       = aws_cloudwatch_event_rule.bot_detection_rule.name
}