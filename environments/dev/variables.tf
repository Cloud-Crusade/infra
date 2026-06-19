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


variable "bastion_instance_type" {
  description = "Bastion host 인스턴스 타입"
  type        = string
  default     = "t3.micro"
}

variable "bastion_key_name" {
  description = "Bastion Host SSH 키페어 이름"
  type        = string
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

variable "cloudfront_zone_id" {
  description = "CloudFront 배포 zone ID (전 세계 고정값)"
  type        = string
  default     = "Z2FDTNDATAQYW2"
}

# ===== CloudWatch =====

variable "alarm_email" {
  description = "Email address to receive CloudWatch alarm notifications"
  type        = string
  default     = ""
}

variable "enable_cloudwatch" {
  description = "CloudWatch 사용 전체 on/off — 알람·대시보드·EKS 컨트롤플레인 로그·APIGW 액세스 로그. off 면 부하테스트 비용 절감(관측은 Prometheus/Grafana)"
  type        = bool
  default     = true
}

variable "enable_container_insights" {
  description = "EKS Container Insights(amazon-cloudwatch-observability 애드온) 사용 여부. enable_cloudwatch=false 인 부하테스트 구간엔 자동 비활성(관측은 Prometheus/Grafana 대체)"
  type        = bool
  default     = true
}


# AWS Parameters and Secrets Lambda Extension (ap-northeast-2, x86_64)
# captcha Lambda 가 Secrets Manager 를 런타임 캐시 조회할 때 사용. 버전은 최신 확인 후 갱신
variable "secrets_extension_layer_arn" {
  description = "AWS Parameters and Secrets Lambda Extension 레이어 ARN"
  type        = string
  default     = "arn:aws:lambda:ap-northeast-2:738900069198:layer:AWS-Parameters-and-Secrets-Lambda-Extension:11"
}

# ===== CAPTCHA =====

variable "captcha_enabled" {
  description = "예매 캡차(ALTCHA PoW) 활성화 — 앱 CAPTCHA_ENABLED 환경변수로 주입"
  type        = bool
  default     = false
}


# ============================================================
# EKS
# ============================================================
variable "eks_cluster_version" {
  description = "Kubernetes 버전"
  type        = string
}

variable "eks_endpoint_public_access" {
  type    = bool
  default = true
}

variable "eks_endpoint_private_access" {
  type    = bool
  default = true
}

variable "eks_endpoint_public_access_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "eks_enabled_log_types" {
  type    = list(string)
  default = ["api", "audit", "authenticator"]
}

variable "eks_system_ng_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "eks_system_ng_capacity_type" {
  type    = string
  default = "ON_DEMAND"
}

variable "eks_system_ng_desired_size" {
  type    = number
  default = 1
}

variable "eks_system_ng_min_size" {
  type    = number
  default = 1
}

variable "eks_system_ng_max_size" {
  type    = number
  default = 2
}

variable "eks_app_ng_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "eks_app_ng_capacity_type" {
  type    = string
  default = "ON_DEMAND"
}

variable "eks_app_ng_desired_size" {
  type    = number
  default = 1
}

variable "eks_app_ng_min_size" {
  type    = number
  default = 1
}

variable "eks_app_ng_max_size" {
  type    = number
  default = 3
}

variable "ticketing_image_tag" {
  description = "EKS 워크로드 초기 이미지 태그 (이후 롤아웃은 cc/app CD 가 갱신 → image 변경은 terraform ignore)"
  type        = string
  default     = "latest"
}

variable "eks_access_entries" {
  type = list(object({
    principal_arn     = string
    kubernetes_groups = optional(list(string), [])
    type              = optional(string, "STANDARD")
    policy_arn        = optional(string, null)
  }))
  default = []
}

# TargetGroupBinding(kubernetes_manifest)은 plan 시 클러스터+CRD 접속이 필요 → clean-room plan 에선 false.
# LB Controller(CRD) 설치 후 2단계로 true 적용(TF_VAR_enable_nlb_binding=true).
variable "enable_nlb_binding" {
  description = "NLB 타겟그룹 ↔ 파드 IP TargetGroupBinding 생성 여부"
  type        = bool
  default     = false
}

variable "enable_az_failover" {
  description = "AZ Failover(NLB zonal shift + RDS Multi-AZ, 추후 ARC) 일괄 on/off. off 면 cross-zone 모드"
  type        = bool
  default     = false
}

# API GW 백엔드 선택 — eks(NLB→파드) | test_ec2(단일 nginx 게이트웨이, 디버깅·부하테스트)
variable "api_backend" {
  description = "API Gateway 백엔드: eks | test_ec2"
  type        = string
  default     = "eks"
  validation {
    condition     = contains(["eks", "test_ec2"], var.api_backend)
    error_message = "api_backend 는 'eks' 또는 'test_ec2' 여야 합니다."
  }
}

# ticketing 서비스 수신 포트 단일 소스 — NLB 타겟그룹 port·파드 SG 인바운드·TargetGroupBinding serviceRef 가 공유.
# eks 서비스 모듈 http_port(기본 8000)와 일치해야 함.
variable "ticketing_http_port" {
  description = "ticketing 서비스 HTTP 포트 (NLB 타겟·SG·TargetGroupBinding 공통)"
  type        = number
  default     = 8000
}

# ===== ops / test_ec2 (테스트 픽스처) =====
variable "test_image_registry" {
  description = "ECR 레지스트리 override. 미설정 시 현재 계정·리전에서 파생"
  type        = string
  default     = ""
}

variable "ecr_namespace" {
  description = "ECR 리포지토리 네임스페이스 prefix (cc/app CD vars.ECR_NAMESPACE 와 동일)"
  type        = string
  default     = "ticketing"
}

variable "test_image_tag" {
  type    = string
  default = "latest"
}

variable "test_service_port" {
  description = "nginx 게이트웨이 포트 (API Gateway 백엔드). 서비스 직접 포트는 +1..+4"
  type        = number
  default     = 8000
}

variable "test_ec2_instance_type" {
  type    = string
  default = "t3.small"
}

variable "test_ec2_root_volume_gb" {
  type    = number
  default = 30
}

variable "test_service_ingress_cidrs" {
  description = "서비스 포트 인바운드 허용 CIDR (테스트 편의상 기본 전체 — 운영 금지)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
