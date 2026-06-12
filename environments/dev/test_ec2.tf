# =========================================================
# dev 통합 테스트용 EC2 — ECR 서비스 레이어 이미지 구동
# (임시 테스트 픽스처: 테스트 종료 후 이 파일만 제거하면 됨)
# =========================================================

variable "test_image_registry" {
  description = "ECR 레지스트리 override (예: <acct>.dkr.ecr.<region>.amazonaws.com). 미설정 시 본 구성의 ECR repo 에서 파생. 이미지는 <registry>/<namespace>/<svc>:<tag>"
  type        = string
  default     = ""
}

variable "test_image_tag" {
  description = "<namespace>/<svc> 이미지 태그"
  type        = string
  default     = "latest"
}

variable "test_service_port" {
  description = "nginx 게이트웨이 포트 (API Gateway 백엔드). 서비스 직접 포트는 +1..+4"
  type        = number
  default     = 8000
}

variable "test_ec2_instance_type" {
  description = "테스트 EC2 인스턴스 타입"
  type        = string
  default     = "t3.small"
}

variable "test_ec2_root_volume_gb" {
  description = "테스트 EC2 루트 EBS 볼륨 크기(GB) — 서비스 이미지 추출에 충분해야 함"
  type        = number
  default     = 30
}

variable "test_service_ingress_cidrs" {
  description = "서비스 포트 인바운드 허용 CIDR (테스트 편의상 기본 전체 — 운영 금지)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# 최신 Amazon Linux 2023 (x86_64)
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

# ECR pull 권한 인스턴스 프로파일
data "aws_iam_policy_document" "test_ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "test_ec2" {
  name               = "${var.project_name}-${var.environment}-test-ec2"
  assume_role_policy = data.aws_iam_policy_document.test_ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "test_ec2_ecr" {
  role       = aws_iam_role.test_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# 앱이 예약 큐로 produce — 인스턴스 롤로 SQS 접근(정적 키 미사용)
resource "aws_iam_role_policy" "test_ec2_sqs" {
  role = aws_iam_role.test_ec2.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sqs:SendMessage", "sqs:GetQueueUrl", "sqs:GetQueueAttributes"]
      Resource = module.sqs.queue_arn
    }]
  })
}

resource "aws_iam_instance_profile" "test_ec2" {
  name = "${var.project_name}-${var.environment}-test-ec2"
  role = aws_iam_role.test_ec2.name
}

# 테스트 EC2 보안 그룹 (서비스 포트 + SSH)
resource "aws_security_group" "test_ec2" {
  name        = "${var.project_name}-${var.environment}-test-ec2-sg"
  description = "Test EC2 running ECR service image"
  vpc_id      = module.vpc.vpc_id

  # nginx 게이트웨이(8000) + 서비스 직접 디버깅 포트(8001-8004)
  ingress {
    description = "nginx gateway + per-service debug ports"
    from_port   = var.test_service_port
    to_port     = var.test_service_port + 4
    protocol    = "tcp"
    cidr_blocks = var.test_service_ingress_cidrs
  }

  ingress {
    description = "ssh"
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
    Name = "${var.project_name}-${var.environment}-test-ec2-sg"
  }
}

resource "aws_instance" "test_service" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.test_ec2_instance_type
  subnet_id                   = module.vpc.public_subnet_ids[0]
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.test_ec2.id, module.security_groups.eks_sg_id]
  iam_instance_profile        = aws_iam_instance_profile.test_ec2.name
  key_name                    = aws_key_pair.bastion.key_name

  # 기본 8GB 로는 서비스 이미지(uv 캐시 등) 추출 시 디스크 부족 → 루트 볼륨 확대
  root_block_device {
    volume_size = var.test_ec2_root_volume_gb
    volume_type = "gp3"
  }

  # docker 설치 → ECR 로그인 → 이미지 pull → run (.env 마운트)
  # 별도 템플릿 사용: HCL heredoc 들여쓰기로 shebang 이 깨져 cloud-init 미실행되던 문제 방지
  user_data = templatefile("${path.module}/templates/test_ec2_user_data.sh.tftpl", {
    region = var.aws_region
    # 기본은 본 구성의 ECR 레지스트리(ticketing repo 와 동일 계정) — 필요 시 var 로 override
    registry               = var.test_image_registry != "" ? var.test_image_registry : split("/", aws_ecr_repository.ticketing["auth"].repository_url)[0]
    namespace              = var.ecr_namespace
    tag                    = var.test_image_tag
    port                   = var.test_service_port
    core_writer_url        = "postgresql+asyncpg://${var.db_username}:${var.db_password}@${module.rds.primary_endpoint}/${var.db_name}"
    core_reader_url        = "postgresql+asyncpg://${var.db_username}:${var.db_password}@${module.rds.primary_replica_endpoint}/${var.db_name}"
    reservation_writer_url = "postgresql+asyncpg://${var.db_username}:${var.db_password}@${module.rds.reservation_endpoint}/${var.db_name}"
    reservation_reader_url = "postgresql+asyncpg://${var.db_username}:${var.db_password}@${module.rds.reservation_replica_endpoint}/${var.db_name}"
    redis_url              = "redis://${module.elasticache.main_cache_endpoint}:6379/0"
    jwt_secret             = random_password.authorization.result
    captcha_enabled        = var.captcha_enabled
    captcha_hmac_secret    = random_password.captcha_hmac.result
    sqs_queue_url          = module.sqs.queue_url
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-test-service"
  }
}

output "test_service_public_ip" {
  description = "테스트 EC2 퍼블릭 IP"
  value       = aws_instance.test_service.public_ip
}

output "test_service_public_dns" {
  description = "테스트 EC2 퍼블릭 DNS (API Gateway 예약 백엔드 등 연결용)"
  value       = aws_instance.test_service.public_dns
}
