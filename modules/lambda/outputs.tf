output "function_names" {
  description = "모듈명 → Lambda 함수 이름"
  value       = { for k, f in aws_lambda_function.this : k => f.function_name }
}

output "function_arns" {
  description = "모듈명 → Lambda ARN"
  value       = { for k, f in aws_lambda_function.this : k => f.arn }
}

output "function_urls" {
  description = "모듈명 → Function URL (생성된 모듈만)"
  value       = { for k, u in aws_lambda_function_url.this : k => u.function_url }
}
