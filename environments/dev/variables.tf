# ===== 공통 =====

variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "environment" {
  description = "배포 환경 (dev | prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment 값은 'dev' 또는 'prod' 이어야 합니다."
  }
}

variable "project_name" {
  description = "프로젝트 이름 (리소스 태그 및 네이밍에 사용)"
  type        = string
  default     = "ktcloud-cc-infra"
}

# ===== VPC =====

variable "vpc_cidr" {
  description = "VPC CIDR 블록"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "퍼블릭 서브넷 CIDR 목록"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "프라이빗 서브넷 CIDR 목록"
  type        = list(string)
}

variable "availability_zones" {
  description = "사용할 가용 영역 목록"
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "NAT Gateway 생성 여부 (dev 환경에서는 비용 절감을 위해 기본값 false)"
  type        = bool
  default     = false
}

# ===== Security Group =====

variable "allowed_ssh_cidrs" {
  description = "Bastion host SSH 접근 허용 IP 목록"
  type        = list(string)
}

# ===== Bastion =====

variable "bastion_ami" {
  description = "Bastion Host AMI"
  type        = string
}

variable "bastion_instance_type" {
  description = "Bastion host 인스턴스 타입"
  type        = string
  default     = "t3.micro"
}

variable "bastion_key_name" {
  description = "Bastion Host SSH 키페어 이름"
  type        = string
}

# ===== IAM =====

variable "oidc_provider_arn" {
  description = "EKS OIDC Provider ARN"
  type        = string
  default     = ""
}

variable "oidc_provider_url" {
  description = "EKS OIDC Provider URL"
  type        = string
  default     = ""
}

# ===== RDS =====

variable "db_name" {
  description = "RDS 데이터베이스 이름"
  type        = string
  default     = "ccdb"
}

variable "db_username" {
  description = "RDS 마스터 사용자 이름"
  type        = string
}

variable "db_password" {
  description = "RDS 마스터 비밀번호 (평문 tfvars 금지 — CI 는 Secret DB_PASSWORD, 로컬은 TF_VAR_db_password)"
  type        = string
  sensitive   = true
}

variable "db_engine_version" {
  description = "RDS 엔진 버전"
  type        = string
  default     = "13.18"
}

variable "db_instance_class" {
  description = "RDS 인스턴스 타입"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "RDS 스토리지 크기 (GB)"
  type        = number
  default     = 20
}

# ===== Public 버킷 =====

variable "public_bucket" {
  description = "공개 접근 S3 버킷 이름 (web 정적 호스팅 + 공개 리소스 + JWT 공개키, state 버킷과 분리). CloudFront origin 도 이 버킷"
  type        = string
}

variable "public_bucket_domain_name" {
  description = "공개 접근 S3 버킷의 리전별 도메인 이름 (예: my-bucket.s3.ap-northeast-2.amazonaws.com)"
  type        = string
}

# ===== Route53 / 도메인 =====

variable "domain_name" {
  description = "기본 도메인 이름 (예: einsof.app)"
  type        = string
}

variable "route53_zone_id" {
  description = "기존 Route53 호스팅 영역 ID (도메인 등록 시 생성된 존을 참조)"
  type        = string
}

variable "alb_dns_name" {
  description = "api 레코드가 가리킬 ALB(서버, EKS ingress 등)의 DNS Name"
  type        = string
}

variable "alb_zone_id" {
  description = "ALB 의 호스팅 zone ID (서울 리전 ALB 고정값)"
  type        = string
  default     = "Z3F1SLL3L0ST3L"
}

variable "cloudfront_zone_id" {
  description = "CloudFront 배포 zone ID (전 세계 고정값)"
  type        = string
  default     = "Z2FDTNDATAQYW2"
}