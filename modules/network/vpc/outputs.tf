output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "퍼블릭 서브넷 ID 목록"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "프라이빗 서브넷 ID 목록"
  value       = aws_subnet.private[*].id
}

output "vpc_cidr" {
  description = "VPC CIDR 블록"
  value       = aws_vpc.this.cidr_block
}

output "secretsmanager_endpoint_security_group_id" {
  description = "Secrets Manager 인터페이스 엔드포인트 SG ID (인바운드 규칙은 상위 구성에서 부여)"
  value       = try(aws_security_group.secretsmanager_endpoint[0].id, null)
}
