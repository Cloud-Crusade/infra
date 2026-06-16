resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-${var.environment}-bastion-sg"
  description = "Security Group for Bastion host"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-bastion-sg"
  }
}

# standalone 규칙 사용 — pod(클러스터 primary SG)로부터의 인바운드를 shared 교차 규칙으로 추가하기 위함
# (인라인 ingress 와 aws_security_group_rule 은 동일 SG 에 혼용 불가)
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Security Group for RDS instances"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-sg"
  }
}

resource "aws_security_group_rule" "rds_from_bastion" {
  type                     = "ingress"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = aws_security_group.bastion.id
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
}

resource "aws_security_group_rule" "rds_from_lambda" {
  type                     = "ingress"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = aws_security_group.lambda.id
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
}

# 전 포트 허용(protocol -1)하되 목적지는 VPC 내부로만 한정
resource "aws_security_group_rule" "rds_egress" {
  type              = "egress"
  security_group_id = aws_security_group.rds.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [var.vpc_cidr]
}

resource "aws_security_group" "eks" {
  name        = "${var.project_name}-${var.environment}-eks-sg"
  description = "Security Group for EKS"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 6443
    to_port         = 6443
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-eks-sg"
  }
}

resource "aws_security_group" "cache" {
  name        = "${var.project_name}-${var.environment}-cache-sg"
  description = "Security Group for ElastiCache (Redis/Valkey)"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-${var.environment}-cache-sg"
  }
}

# Redis 인바운드는 서비스 SG 로 제한 — VPC 전체 개방 회피(최소 권한). pod(primary SG)는 shared 교차 규칙
resource "aws_security_group_rule" "cache_from_lambda" {
  type                     = "ingress"
  security_group_id        = aws_security_group.cache.id
  source_security_group_id = aws_security_group.lambda.id
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
}

resource "aws_security_group_rule" "cache_egress" {
  type              = "egress"
  security_group_id = aws_security_group.cache.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

# VPC 연결 람다용 SG (egress 로 ElastiCache/RDS 등 접근)
resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-${var.environment}-lambda-sg"
  description = "Security Group for VPC-attached Lambdas"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-lambda-sg"
  }
}