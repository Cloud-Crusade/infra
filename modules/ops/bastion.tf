data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
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
  subnet_id                   = var.public_subnet_ids[0]
  vpc_security_group_ids      = [var.bastion_sg_id]
  key_name                    = aws_key_pair.bastion.key_name
  associate_public_ip_address = true

  tags = {
    Name = "${var.project_name}-${var.environment}-bastion"
  }

  user_data = <<-EOF
                #!/bin/bash
                # docker compsoe 설치
                mkdir -p /usr/libexec/docker/cli-plugins/
                curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m)" -o /usr/libexec/docker/cli-plugins/docker-compose
                chmod +x /usr/libexec/docker/cli-plugins/docker-compose

                # k6(+xk6-sql) compose 구성 — bastion 직접 설치(dnf/xk6) 대신 컨테이너로 실행
                mkdir -p /home/ec2-user/k6/scripts
                cat > /home/ec2-user/k6/docker-compose.yml <<'K6COMPOSE'
                ${file("${path.module}/compose/k6/docker-compose.yml")}
                K6COMPOSE
                cat > /home/ec2-user/k6/Dockerfile <<'K6DOCKERFILE'
                ${file("${path.module}/compose/k6/Dockerfile")}
                K6DOCKERFILE
                # xk6-sql 커스텀 k6 이미지 사전 빌드(최초 1회, 실패해도 부팅 계속)
                cd /home/ec2-user/k6 && docker compose build k6-sql || true

                # grafana compose 파일 생성
                mkdir -p /home/ec2-user/grafana
                cat > /home/ec2-user/grafana/docker-compose.yml <<'COMPOSE'
                ${file("${path.module}/compose/grafana/docker-compose.yml")}
                COMPOSE

                # grafana 실행
                cd /home/ec2-user/grafana
                docker compose up -d
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
