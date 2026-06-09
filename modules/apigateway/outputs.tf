output "api_id" {
  description = "REST API ID"
  value       = aws_api_gateway_rest_api.this.id
}

output "invoke_url" {
  description = "스테이지 호출 URL"
  value       = aws_api_gateway_stage.this.invoke_url
}

output "domain_regional_target" {
  description = "커스텀 도메인의 regional 타겟 DNS (Route53 alias 용)"
  value       = aws_api_gateway_domain_name.api.regional_domain_name
}

output "domain_regional_zone_id" {
  description = "커스텀 도메인 regional 호스팅 zone ID (Route53 alias 용)"
  value       = aws_api_gateway_domain_name.api.regional_zone_id
}
