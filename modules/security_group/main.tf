resource "aws_security_group" "bastion" {
  name        = "${var.PROJECT_NAME}-${var.ENVIRONMENT}-bastion-sg"
  description = "Security Group for Bastion host"
  vpc_id      = var.VPC_ID

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ALLOWED_SSH_CIDRS
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.PROJECT_NAME}-${var.ENVIRONMENT}-bastion-sg"
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.PROJECT_NAME}-${var.ENVIRONMENT}-rds-sg"
  description = "Security Group for RDS instances"
  vpc_id      = var.VPC_ID

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id, aws_security_group.bastion.id]
  }

  egress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.PROJECT_NAME}-${var.ENVIRONMENT}-rds-sg"
  }
}

resource "aws_security_group" "eks" {
  name        = "${var.PROJECT_NAME}-${var.ENVIRONMENT}-eks-sg"
  description = "Security Group for EKS"
  vpc_id      = var.VPC_ID

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
    Name = "${var.PROJECT_NAME}-${var.ENVIRONMENT}-eks-sg"
  }
}