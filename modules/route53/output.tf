output "www_record_fqdn" {
  description = "www 레코드 FQDN (CloudFront 매핑)"
  value       = aws_route53_record.www.fqdn
}

output "api_record_fqdn" {
  description = "api 레코드 FQDN (ALB 매핑)"
  value       = aws_route53_record.api.fqdn
}
