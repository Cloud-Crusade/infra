output "api_id" {
  description = "HTTP API ID"
  value       = aws_apigatewayv2_api.this.id
}

output "api_endpoint" {
  description = "HTTP API 호출 엔드포인트"
  value       = aws_apigatewayv2_api.this.api_endpoint
}
