output "private_key_secret_arn" {
  description = "Private Key 시크릿 ARN"
  value       = aws_secretsmanager_secret.private_key.arn
}

output "rds_credentials_secret_arn" {
  description = "RDS 접속 정보 시크릿 ARN"
  value       = aws_secretsmanager_secret.rds_credentials.arn
}

output "rds_writer_endpoint_secret_arn" {
  description = "RDS Writer 엔드포인트 시크릿 ARN"
  value       = aws_secretsmanager_secret.rds_writer_endpoint.arn
}
