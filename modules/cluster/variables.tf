# ================== 공통 ==================
variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

# aws_lb_controller 차트 values
variable "vpc_id" {
  type = string
}

# prometheus server internal NLB source-ranges (VPC 내부 접근 허용)
variable "vpc_cidr" {
  type    = string
  default = ""
}

# ================== eks 클러스터 ==================
variable "subnet_ids" {
  type = list(string)
}

variable "eks_sg_id" {
  type = string
}

variable "cluster_version" {
  type = string
}

variable "cluster_endpoint_public_access" {
  type = bool
}

variable "cluster_endpoint_private_access" {
  type = bool
}

variable "cluster_endpoint_public_access_cidrs" {
  type = list(string)
}

variable "cluster_enabled_log_types" {
  type = list(string)
}

variable "access_entries" {
  type = list(object({
    principal_arn     = string
    kubernetes_groups = optional(list(string), [])
    type              = optional(string, "STANDARD")
    policy_arn        = optional(string, null)
  }))
  default = []
}

# ================== 노드 그룹(system/app) ==================
variable "system_ng_instance_types" {
  type = list(string)
}

variable "system_ng_capacity_type" {
  type = string
}

variable "system_ng_desired_size" {
  type = number
}

variable "system_ng_min_size" {
  type = number
}

variable "system_ng_max_size" {
  type = number
}

variable "app_ng_instance_types" {
  type = list(string)
}

variable "app_ng_capacity_type" {
  type = string
}

variable "app_ng_desired_size" {
  type = number
}

variable "app_ng_min_size" {
  type = number
}

variable "app_ng_max_size" {
  type = number
}

# ================== 워크로드(ticketing) ==================
variable "domain_name" {
  type = string
}

variable "captcha_enabled" {
  type = bool
}

variable "ticketing_image_tag" {
  type = string
}

variable "ecr_namespace" {
  type = string
}

variable "ecr_registry" {
  type = string
}

# ================== data 레이어 엔드포인트(ExternalName 타깃) ==================
variable "rds_core_writer_endpoint" {
  type = string
}

variable "rds_core_reader_endpoint" {
  type = string
}

variable "rds_reservation_writer_endpoint" {
  type = string
}

variable "rds_reservation_reader_endpoint" {
  type = string
}

variable "redis_main_endpoint" {
  type = string
}

# ================== async 레이어(예약 큐) ==================
variable "sqs_queue_url" {
  type = string
}

variable "sqs_queue_arn" {
  type = string
}

# ================== 공유 시크릿(검증측과 공유) ==================
variable "jwt_secret" {
  type      = string
  sensitive = true
}

variable "captcha_hmac_secret" {
  type      = string
  sensitive = true
}

# ================== DB 롤 부트스트랩(master) ==================
variable "db_name" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "svc_role_passwords" {
  description = "서비스 DB 롤(auth_svc 등)별 비밀번호 (data 레이어 생성, 프록시 auth 와 동일)"
  type        = map(string)
  sensitive   = true
  default     = {}
}

variable "enable_container_insights" {
  description = "CloudWatch Container Insights(amazon-cloudwatch-observability 애드온) 활성화 — EKS 노드/파드 메트릭을 CloudWatch 로 전송"
  type        = bool
  default     = false
}
