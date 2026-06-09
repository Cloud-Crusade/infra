output "www_record_fqdn" {
  description = "www 레코드 FQDN (CloudFront 매핑)"
  value       = aws_route53_record.www.fqdn
}

output "api_record_fqdn" {
  description = "api 레코드 FQDN (트래픽 라우팅 대상 매핑)"
  value       = aws_route53_record.api.fqdn
}
