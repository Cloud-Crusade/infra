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

# bastion 이 prometheus internal NLB DNS 를 런타임 조회(읽기 전용 ELB describe만)
resource "aws_iam_role" "bastion" {
  name = "${var.project_name}-${var.environment}-bastion-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "bastion_elb_describe" {
  name = "elb-describe"
  role = aws_iam_role.bastion.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "elasticloadbalancing:DescribeLoadBalancers"
      Resource = "*"
    }]
  })
}

# 부팅 시 ops 파일 S3 sync 용 읽기 권한
resource "aws_iam_role_policy" "bastion_s3_ops" {
  name = "s3-ops-read"
  role = aws_iam_role.bastion.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "arn:aws:s3:::${local.ops_bucket}/bastion/${var.environment}/ops/*"
      },
      {
        Effect    = "Allow"
        Action    = ["s3:ListBucket"]
        Resource  = "arn:aws:s3:::${local.ops_bucket}"
        Condition = { StringLike = { "s3:prefix" = "bastion/${var.environment}/ops/*" } }
      }
    ]
  })
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.project_name}-${var.environment}-bastion-profile"
  role = aws_iam_role.bastion.name
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.bastion_instance_type
  subnet_id                   = var.public_subnet_ids[0]
  vpc_security_group_ids      = [var.bastion_sg_id]
  key_name                    = aws_key_pair.bastion.key_name
  iam_instance_profile        = aws_iam_instance_profile.bastion.name
  associate_public_ip_address = true

  tags = {
    Name = "${var.project_name}-${var.environment}-bastion"
  }

  # ops 파일(scripts/·compose/)은 S3 에 업로드하고 부팅 시 sync — user_data 16KB 한도 회피(인라인 대신).
  user_data_base64 = base64gzip(templatefile("${path.module}/templates/bastion_user_data.sh.tftpl", {
    ops_bucket         = local.ops_bucket
    ops_prefix         = "bastion/${var.environment}/ops"
    prometheus_lb_name = "${var.project_name}-${var.environment}-prometheus"
    aws_region         = var.aws_region
  }))

  # 부팅 전 ops 파일이 S3 에 존재하도록 보장
  depends_on = [aws_s3_object.ops]
}

# scripts/·compose/ 전체 파일을 S3 에 업로드(부팅 시 bastion 이 sync). state 버킷 재사용.
locals {
  ops_bucket = "tfstate-bucket-d8f5bb8d" # backend.tf 의 state 버킷
}

resource "aws_s3_object" "ops" {
  for_each = fileset(path.module, "{scripts,compose}/**")
  bucket   = local.ops_bucket
  key      = "bastion/${var.environment}/ops/${each.value}"
  source   = "${path.module}/${each.value}"
  etag     = filemd5("${path.module}/${each.value}")
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
