# VPC 내부(프라이빗) Lambda 가 NAT 없이 Secrets Manager 에 닿도록 — 인터페이스 엔드포인트(private)
# 비-VPC Lambda(captcha/authorizer)는 인터넷 경로를 쓰므로 이 엔드포인트가 필요 없다(VPC/비-VPC 분리).
data "aws_region" "current" {}

resource "aws_security_group" "secretsmanager_endpoint" {
  count       = var.enable_secretsmanager_endpoint ? 1 : 0
  name        = "${var.project_name}-${var.environment}-sm-endpoint-sg"
  description = "Secrets Manager VPC endpoint - inbound 443 from allowed SGs"
  vpc_id      = aws_vpc.this.id

  # 인바운드(443)는 실제 SM 접근이 필요한 SG 만 허용 — 규칙은 외부(상위 구성)에서 부여(최소권한, 모듈 순환 회피)
  tags = {
    Name = "${var.project_name}-${var.environment}-sm-endpoint-sg"
  }
}

resource "aws_vpc_endpoint" "secretsmanager" {
  count               = var.enable_secretsmanager_endpoint ? 1 : 0
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.secretsmanager_endpoint[0].id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project_name}-${var.environment}-secretsmanager-endpoint"
  }
}
