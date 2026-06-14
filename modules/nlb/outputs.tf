output "nlb_arn" {
  description = "NLB ARN"
  value       = aws_lb.this.arn
}

output "nlb_id" {
  description = "NLB ID"
  value       = aws_lb.this.id
}

output "nlb_dns_name" {
  description = "NLB DNS 이름"
  value       = aws_lb.this.dns_name
}

output "nlb_zone_id" {
  description = "NLB Route 53 호스팅 영역 ID"
  value       = aws_lb.this.zone_id
}
