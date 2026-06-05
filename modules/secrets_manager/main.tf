# ==============================
# Secrets Manager 시크릿 정의
# ==============================

# Private Key 시크릿
# Lambda가 JWT 토큰 서명 시 사용하는 비공개 키
resource "aws_secretsmanager_secret" "private_key" {
  name        = "${var.project_name}-${var.environment}-private-key"
  description = "JWT 서명용 Private Key"

  tags = {
    Name = "${var.project_name}-${var.environment}-private-key"
  }
}

resource "aws_secretsmanager_secret_version" "private_key" {
  secret_id     = aws_secretsmanager_secret.private_key.id
  secret_string = var.private_key_value
}

# RDS 접속 정보 시크릿
# EKS Pod 및 Lambda가 RDS 접속 시 사용
resource "aws_secretsmanager_secret" "rds_credentials" {
  name        = "${var.project_name}-${var.environment}-rds-credentials"
  description = "RDS 접속 정보 (username, password)"

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-credentials"
  }
}

resource "aws_secretsmanager_secret_version" "rds_credentials" {
  secret_id = aws_secretsmanager_secret.rds_credentials.id
  secret_string = jsonencode({
    username = var.rds_username
    password = var.rds_password
  })
}

# RDS Writer 엔드포인트 시크릿
# AZ 장애 시 동적 전환을 위한 Writer 엔드포인트
resource "aws_secretsmanager_secret" "rds_writer_endpoint" {
  name        = "${var.project_name}-${var.environment}-rds-writer-endpoint"
  description = "RDS Writer 엔드포인트 (AZ 장애 시 동적 전환용)"

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-writer-endpoint"
  }
}

resource "aws_secretsmanager_secret_version" "rds_writer_endpoint" {
  secret_id     = aws_secretsmanager_secret.rds_writer_endpoint.id
  secret_string = var.rds_writer_endpoint
}
