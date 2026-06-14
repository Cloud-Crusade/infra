variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "environment" {
  description = "배포 환경 (dev | prod)"
  type        = string
}

variable "subnet_ids" {
  description = "노드 그룹 배치 서브넷 ID 목록 (private subnet 권장)"
  type        = list(string)
}

variable "additional_security_group_ids" {
  description = "클러스터에 추가로 연결할 보안 그룹 ID 목록"
  type        = list(string)
  default     = []
}

variable "cluster_role_arn" {
  description = "EKS 클러스터 컨트롤 플레인에 부여할 IAM 역할 ARN"
  type        = string
}

variable "node_role_arn" {
  description = "EKS 노드 그룹 EC2 인스턴스에 부여할 IAM 역할 ARN"
  type        = string
}

variable "vpc_cni_role_arn" {
  description = "vpc-cni 애드온 IRSA용 IAM 역할 ARN"
  type        = string
}

variable "ebs_csi_role_arn" {
  description = "aws-ebs-csi-driver 애드온 IRSA용 IAM 역할 ARN"
  type        = string
}

# ============================================================
# 클러스터
# ============================================================
variable "cluster_version" {
  description = "Kubernetes 버전 (예: \"1.31\")"
  type        = string
}

variable "cluster_endpoint_public_access" {
  description = "퍼블릭 엔드포인트 활성화 여부"
  type        = bool
  default     = true
}

variable "cluster_endpoint_private_access" {
  description = "프라이빗 엔드포인트 활성화 여부"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "퍼블릭 엔드포인트 접근 허용 CIDR 목록"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cluster_enabled_log_types" {
  description = "활성화할 컨트롤 플레인 로그 타입 목록 (비용 발생 — 필요한 것만 선택)"
  type        = list(string)
  default     = ["api", "audit", "authenticator"]
}

# System 노드 그룹
variable "system_ng_instance_types" {
  type    = list(string)
  default = ["t3.small"]
}

variable "system_ng_capacity_type" {
  description = "ON_DEMAND | SPOT"
  type        = string
  default     = "ON_DEMAND"
}

variable "system_ng_desired_size" {
  type    = number
  default = 1
}

variable "system_ng_min_size" {
  type    = number
  default = 1
}

variable "system_ng_max_size" {
  type    = number
  default = 2
}

variable "system_ng_disk_size" {
  type    = number
  default = 20
}

# App 노드 그룹
variable "app_ng_instance_types" {
  type    = list(string)
  default = ["t3.small"]
}

variable "app_ng_capacity_type" {
  description = "ON_DEMAND | SPOT"
  type        = string
  default     = "ON_DEMAND"
}

variable "app_ng_desired_size" {
  type    = number
  default = 1
}

variable "app_ng_min_size" {
  type    = number
  default = 1
}

variable "app_ng_max_size" {
  type    = number
  default = 3
}

variable "app_ng_disk_size" {
  type    = number
  default = 30
}


# 클러스터 접근 제어
variable "access_entries" {
  description = "클러스터에 접근 권한을 부여할 IAM Principal 목록 (EKS Access Entry 방식)"
  type = list(object({
    principal_arn     = string
    kubernetes_groups = optional(list(string), [])
    type              = optional(string, "STANDARD")
    policy_arn        = optional(string, null) # ex) AmazonEKSClusterAdminPolicy
  }))
  default = []
}

# ============================================================
# MSA 워크로드 (ticketing 4서비스 인클러스터 배선)
# ============================================================
variable "aws_region" {
  description = "워크로드 ConfigMap(AWS_REGION) 주입용 리전"
  type        = string
}

variable "domain_name" {
  description = "CORS 허용 오리진(https://www.<domain>) 구성용 기본 도메인"
  type        = string
}

variable "captcha_enabled" {
  description = "캡차(ALTCHA PoW) 활성화 — 앱 CAPTCHA_ENABLED 주입"
  type        = bool
  default     = false
}

variable "ticketing_image_tag" {
  description = "워크로드 초기 이미지 태그 (이후 롤아웃은 cc/app CD 가 갱신 → image 변경은 terraform ignore)"
  type        = string
  default     = "latest"
}

variable "ecr_registry" {
  description = "ECR 레지스트리 호스트 (<account_id>.dkr.ecr.<region>.amazonaws.com). 리포지토리(ticketing-<svc>)는 terraform 밖에서 선행 생성"
  type        = string
}

# RDS/ElastiCache 고정 DNS(ExternalName) 타깃 — host:port 형식 그대로 받아 모듈 내부에서 포트 분리
variable "rds_core_writer_endpoint" {
  description = "core writer RDS 엔드포인트 (host:port)"
  type        = string
}

variable "rds_core_reader_endpoint" {
  description = "core reader RDS 엔드포인트 (host:port)"
  type        = string
}

variable "rds_reservation_writer_endpoint" {
  description = "reservation writer RDS 엔드포인트 (host:port)"
  type        = string
}

variable "rds_reservation_reader_endpoint" {
  description = "reservation reader RDS 엔드포인트 (host:port)"
  type        = string
}

variable "redis_main_endpoint" {
  description = "main ElastiCache(redis-main) 엔드포인트 호스트"
  type        = string
}

variable "sqs_queue_url" {
  description = "예약 큐 URL (ConfigMap SQS_RESERVATION_QUEUE_URL)"
  type        = string
}

variable "sqs_queue_arn" {
  description = "예약 큐 ARN (reservation IRSA SendMessage 대상)"
  type        = string
}

# 검증측(API GW authorizer)과 공유하는 시크릿 — 값으로 주입(루트에서 random_password 소유)
variable "jwt_secret" {
  description = "Authorization HS256 대칭키"
  type        = string
  sensitive   = true
}

variable "captcha_hmac_secret" {
  description = "캡차 HMAC 시크릿"
  type        = string
  sensitive   = true
}

# DB 마스터 크리덴셜 — 서비스별 롤 부트스트랩(생성+GRANT)에 사용
variable "db_name" {
  description = "데이터베이스 이름"
  type        = string
}

variable "db_username" {
  description = "DB 마스터 사용자 (롤 부트스트랩용)"
  type        = string
}

variable "db_password" {
  description = "DB 마스터 비밀번호 (롤 부트스트랩용)"
  type        = string
  sensitive   = true
}
