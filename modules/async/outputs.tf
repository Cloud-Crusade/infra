# ================== lambda ==================
output "function_names" {
  value = module.lambda.function_names
}

output "invoke_arns" {
  value = module.lambda.invoke_arns
}

output "function_arns" {
  value = module.lambda.function_arns
}

# ================== sqs ==================
output "queue_arn" {
  value = module.sqs.queue_arn
}

output "queue_url" {
  value = module.sqs.queue_url
}

output "queue_name" {
  value = module.sqs.queue_name
}
