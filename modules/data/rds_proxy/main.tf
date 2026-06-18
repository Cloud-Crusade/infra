# IAM Role — RDS Proxy 가 Secrets Manager 에서 DB 자격증명을 읽을 권한
resource "aws_iam_role" "proxy" {
  name = "${var.project_name}-${var.environment}-rds-proxy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "proxy_secrets" {
  name = "rds-proxy-secrets-access"
  role = aws_iam_role.proxy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = concat([var.db_secret_arn], var.core_role_secret_arns, var.reservation_role_secret_arns)
    }]
  })
}

# ================== Core DB Proxy ==================

resource "aws_db_proxy" "core" {
  name                   = "${var.project_name}-${var.environment}-core-proxy"
  engine_family          = "POSTGRESQL"
  role_arn               = aws_iam_role.proxy.arn
  vpc_security_group_ids = [var.proxy_sg_id]
  vpc_subnet_ids         = var.subnet_ids

  idle_client_timeout = 1800
  require_tls         = false
  debug_logging       = false

  auth {
    auth_scheme = "SECRETS"
    secret_arn  = var.db_secret_arn
    iam_auth    = "DISABLED"
  }

  # 서비스 롤 자격증명 — 앱이 롤(auth_svc/event_svc)로 프록시 경유 접속
  dynamic "auth" {
    for_each = var.core_role_secret_arns
    content {
      auth_scheme = "SECRETS"
      secret_arn  = auth.value
      iam_auth    = "DISABLED"
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-core-proxy"
  }
}

resource "aws_db_proxy_default_target_group" "core" {
  db_proxy_name = aws_db_proxy.core.name

  connection_pool_config {
    max_connections_percent      = 100
    max_idle_connections_percent = 50
  }
}

resource "aws_db_proxy_target" "core" {
  db_instance_identifier = var.core_db_identifier
  db_proxy_name          = aws_db_proxy.core.name
  target_group_name      = aws_db_proxy_default_target_group.core.name
}

# ================== Reservation DB Proxy ==================

resource "aws_db_proxy" "reservation" {
  name                   = "${var.project_name}-${var.environment}-reservation-proxy"
  engine_family          = "POSTGRESQL"
  role_arn               = aws_iam_role.proxy.arn
  vpc_security_group_ids = [var.proxy_sg_id]
  vpc_subnet_ids         = var.subnet_ids

  idle_client_timeout = 1800
  require_tls         = false
  debug_logging       = false

  auth {
    auth_scheme = "SECRETS"
    secret_arn  = var.db_secret_arn
    iam_auth    = "DISABLED"
  }

  # 서비스 롤 자격증명 — 앱이 롤(reservation_svc/payment_svc)로 프록시 경유 접속
  dynamic "auth" {
    for_each = var.reservation_role_secret_arns
    content {
      auth_scheme = "SECRETS"
      secret_arn  = auth.value
      iam_auth    = "DISABLED"
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-reservation-proxy"
  }
}

resource "aws_db_proxy_default_target_group" "reservation" {
  db_proxy_name = aws_db_proxy.reservation.name

  connection_pool_config {
    max_connections_percent      = 100
    max_idle_connections_percent = 50
  }
}

resource "aws_db_proxy_target" "reservation" {
  db_instance_identifier = var.reservation_db_identifier
  db_proxy_name          = aws_db_proxy.reservation.name
  target_group_name      = aws_db_proxy_default_target_group.reservation.name
}
