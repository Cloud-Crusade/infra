output "cloudfront_distribution_id" {
  description = "CloudFront 배포 ID"
  value       = aws_cloudfront_distribution.main.id
}

output "cloudfront_domain_name" {
  description = "CloudFront 도메인 이름"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "cloudfront_arn" {
  description = "CloudFront 배포 ARN"
  value       = aws_cloudfront_distribution.main.arn
}
