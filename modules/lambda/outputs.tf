output "function_url" {
  value       = aws_lambda_function_url.lambda_url.function_url
  description = "람다 함수의 Function URL 주소"
}