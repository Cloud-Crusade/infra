output "authorization_secret_arn" {
  description = "authorization 대칭 시크릿(HS256) ARN"
  value       = aws_secretsmanager_secret.authorization_secret.arn
}

output "reservation_private_key_secret_arn" {
  description = "reservation Private Key 시크릿 ARN"
  value       = aws_secretsmanager_secret.reservation_private_key.arn
}

output "rds_credentials_secret_arn" {
  description = "RDS 접속 정보 시크릿 ARN"
  value       = aws_secretsmanager_secret.rds_credentials.arn
}

output "core_rds_writer_endpoint_secret_arn" {
  description = "메인(core) RDS Writer 엔드포인트 시크릿 ARN"
  value       = aws_secretsmanager_secret.core_rds_writer_endpoint.arn
}

output "reservation_rds_writer_endpoint_secret_arn" {
  description = "예약(reservation) RDS Writer 엔드포인트 시크릿 ARN"
  value       = aws_secretsmanager_secret.reservation_rds_writer_endpoint.arn
}
