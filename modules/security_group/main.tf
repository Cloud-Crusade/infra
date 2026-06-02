resource "aws_security_group" "bastion" {
    name = "${var.project_name}-${var.environment}-bastion-sg"
    description = "Bastion host에 적용하는 Security Group"
    vpc_id = var.vpc_id

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = var.allowed_ssh_cidrs
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${var.project_name}-${var.environment}-bastion-sg"
    }
}

resource "aws_security_group" "rds" {
    name = "${var.project_name}-${var.environment}-rds-sg"
    description = "RDS에 적용하는 Security Group"
    vpc_id = var.vpc_id

    ingress {
        from_port = 3306
        to_port = 3306
        protocol = "tcp"
        security_groups = ["aws_security_groups.bastion.id"]
    }

    egress {
        from_port = 3306
        to_port = 3306
        protocol = "tcp"
        security_groups = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${project_name}-${environment}-rds-sg"
    }
}

resource "aws_security_group" "eks" {
    name = "${var.project_name}-${var.environment}-eks-sg"
    description = "EKS에 적용하는 Security Group"
    vpc_id = var.vpc_id

    ingress {
        from_port = 6443
        to_port = 6443
        protocol = "tcp"
        security_groups = ["aws_security_group.bastion.id"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        self = true
    }

    tags = {
        Name = "${var.project_name}-${var.environment}-eks-sg"
    }
}