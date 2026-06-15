output "role_arn" {
  description = "컨트롤러 IRSA Role ARN"
  value       = aws_iam_role.this.arn
}

output "service_account_name" {
  description = "컨트롤러 ServiceAccount 이름"
  value       = var.service_account_name
}

output "namespace" {
  description = "컨트롤러 네임스페이스"
  value       = var.namespace
}
