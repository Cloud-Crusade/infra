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

# helm_release(컨트롤러 배포) 에 묶이는 순서 핸들 — 소비측 nlb_binding 이 컨트롤러보다 먼저 삭제되도록
output "helm_release_id" {
  description = "ALB 컨트롤러 helm_release ID (nlb_binding destroy 순서 의존)"
  value       = helm_release.this.id
}
