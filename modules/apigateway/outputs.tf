output "api_id" {
  description = "REST API ID"
  value       = aws_api_gateway_rest_api.this.id
}

output "invoke_url" {
  description = "스테이지 호출 URL"
  value       = aws_api_gateway_stage.this.invoke_url
}
