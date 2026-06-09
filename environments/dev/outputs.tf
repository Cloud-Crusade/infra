output "aws_region" {
  description = "배포된 AWS 리전"
  value       = var.aws_region
}

output "environment" {
  description = "현재 배포 환경"
  value       = var.environment
}

output "project_name" {
  description = "프로젝트 이름"
  value       = var.project_name
}

output "bastion_public_ip" {
  description = "Bastion 퍼블릭 IP"
  value       = aws_instance.bastion.public_ip
}