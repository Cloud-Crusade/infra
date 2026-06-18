output "role_arn" {
  description = "CA IRSA Role ARN"
  value       = aws_iam_role.this.arn
}

output "service_account_name" {
  description = "CA ServiceAccount 이름"
  value       = var.service_account_name
}
