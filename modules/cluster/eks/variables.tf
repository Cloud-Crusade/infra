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

# ================== Container Insights (amazon-cloudwatch-observability) ==================
variable "enable_container_insights" {
  description = "CloudWatch Container Insights 활성화 — amazon-cloudwatch-observability 애드온(CloudWatch agent + Fluent Bit)으로 노드/파드 메트릭을 ContainerInsights 네임스페이스로 전송"
  type        = bool
  default     = false
}

variable "cloudwatch_observability_addon_version" {
  description = "amazon-cloudwatch-observability 애드온 버전 (null 이면 EKS 클러스터 호환 기본 버전 사용)"
  type        = string
  default     = null
}

variable "container_insights_container_logs_enabled" {
  description = "Fluent Bit 컨테이너 로그를 CloudWatch Logs 로 전송할지 여부 (로그 인입 비용 토글)"
  type        = bool
  default     = true
}
