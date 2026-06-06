output "aws_region" {
  description = "배포된 AWS 리전"
  value       = var.AWS_REGION
}

output "environment" {
  description = "현재 배포 환경"
  value       = var.ENVIRONMENT
}

output "project_name" {
  description = "프로젝트 이름"
  value       = var.PROJECT_NAME
}
