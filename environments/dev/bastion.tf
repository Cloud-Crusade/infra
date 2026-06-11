data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "tls_private_key" "bastion" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "bastion" {
  key_name   = "${var.project_name}-${var.environment}-bastion-key"
  public_key = tls_private_key.bastion.public_key_openssh
}

resource "local_file" "bastion_private_key" {
  content         = tls_private_key.bastion.private_key_pem
  filename        = "${path.module}/bastion-key.pem"
  file_permission = "0600"
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.bastion_instance_type
  subnet_id                   = module.vpc.public_subnet_ids[0]
  vpc_security_group_ids      = [module.security_groups.bastion_sg_id]
  key_name                    = aws_key_pair.bastion.key_name
  associate_public_ip_address = true

  tags = {
    Name = "${var.project_name}-${var.environment}-bastion"
  }

  user_data = <<-EOF
                #!/bin/bash
                set -e
                exec > /var/log/user-data.log 2>&1

                yum update -y

                # docker
                amazon-linux-extras install -y docker
                systemctl enable docker
                systemctl start docker
                usermod -aG docker ec2-user

                # k6 
                yum install -y https://dl.k6.io/rpm/repo.rpm
                yum install -y k6 --nogpgcheck

                # stress
                yum install -y stress
                EOF
}

# bastion 개인키를 backend(state) 와 동일한 S3 버킷에 업로드 (팀 SSH 접근용)
resource "aws_s3_object" "bastion_private_key" {
  bucket       = "tfstate-bucket-d8f5bb8d" # backend.tf 의 state 버킷
  key          = "bastion/${var.environment}/bastion-key.pem"
  content      = tls_private_key.bastion.private_key_pem
  content_type = "application/x-pem-file"
  # 민감 키 — 객체 단위 SSE 명시(버킷 기본 암호화에 의존하지 않음)
  server_side_encryption = "AES256"
}