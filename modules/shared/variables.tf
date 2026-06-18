# ================== 공통 ==================
variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

# ================== cloudwatch (관측성 대상) ==================
variable "alarm_email" {
  description = "알람 통지 수신 이메일(빈 값이면 SNS 구독 미생성)"
  type        = string
  default     = ""
}

variable "rds_instance_ids" {
  type    = list(string)
  default = []
}

variable "lambda_function_names" {
  type    = list(string)
  default = []
}

variable "cloudfront_distribution_id" {
  type    = string
  default = ""
}

variable "elasticache_cluster_ids" {
  type    = list(string)
  default = []
}

variable "sqs_queue_names" {
  type    = list(string)
  default = []
}

variable "eks_cluster_name" {
  description = "EKS 노드 알람 대상('' 이면 미생성)"
  type        = string
  default     = ""
}

variable "api_gateway_name" {
  description = "API GW 알람 대상('' 이면 미생성)"
  type        = string
  default     = ""
}

# ARC zonal-shift outcome 알람(UnHealthyHostCount) dimension — api 레이어(NLB) 출력에서 주입
variable "lb_arn_suffix" {
  description = "NLB ARN suffix (ARC outcome 알람 LoadBalancer dimension)"
  type        = string
}

variable "target_group_arn_suffixes" {
  description = "서비스명 → 타겟그룹 ARN suffix (ARC outcome 알람 TargetGroup dimension, 전체 집계)"
  type        = map(string)
}

# ================== SG 객체(security_group 서브모듈 입력) ==================
variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "private_subnet_cidrs" {
  description = "EKS 파드(private subnet) → RDS/Cache 접근 허용 CIDR"
  type        = list(string)
}

variable "allowed_ssh_cidrs" {
  description = "bastion SSH 허용 IP"
  type        = list(string)
}

# ================== 교차 SG 규칙 ==================
variable "secretsmanager_endpoint_security_group_id" {
  description = "SM 인터페이스 엔드포인트 SG(인바운드 443 부여 대상)"
  type        = string
}

variable "cluster_security_group_id" {
  description = "NLB→파드 인바운드 부여 대상(클러스터 SG)"
  type        = string
}

variable "nlb_sg_id" {
  description = "파드 인바운드 소스(NLB SG)"
  type        = string
}

variable "ticketing_http_port" {
  description = "ticketing 파드 수신 포트(NLB→파드, nlb_binding serviceRef)"
  type        = number
}

variable "enable_cloudwatch" {
  description = "CloudWatch(알람·대시보드·SNS) 모듈 생성 여부"
  type        = bool
  default     = true
}

variable "enable_az_failover" {
  description = "AZ Failover 활성 시 ARC zonal autoshift 등록(ENABLED). outcome 알람은 CloudWatch → enable_cloudwatch 필요"
  type        = bool
  default     = false
}

variable "lb_arn" {
  description = "ARC zonal autoshift 대상 NLB ARN"
  type        = string
  default     = ""
}

# ================== nlb_binding (NLB 타겟그룹 ↔ 파드) ==================
variable "enable_nlb_binding" {
  description = "TargetGroupBinding 생성 게이트 — clean-room plan 회피(컨트롤러 설치 후 활성화)"
  type        = bool
  default     = false
}

variable "service_targets" {
  description = "서비스별 NLB 타겟그룹 — { <svc> = { target_group_arn } } (api 레이어 출력)"
  type        = any
  default     = {}
}

variable "ticketing_namespace" {
  description = "ticketing 워크로드 네임스페이스(cluster 레이어 출력)"
  type        = string
  default     = ""
}

variable "ticketing_http_service_names" {
  description = "서비스별 k8s Service 이름(cluster 레이어 출력)"
  type        = map(string)
  default     = {}
}

# 컨트롤러 준비 핸들 — nlb_binding 의 생성/삭제 순서 의존(컨트롤러 후 생성, 이전 삭제). 값 자체는 미사용
variable "aws_lb_controller_dependency" {
  description = "ALB 컨트롤러 순서 의존 핸들(role_arn). nlb_binding 이 컨트롤러보다 먼저 삭제되도록"
  type        = string
  default     = ""
}
