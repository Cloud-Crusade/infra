variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "environment" {
  description = "배포 환경"
  type        = string
}

variable "subnet_ids" {
  description = "NLB를 배치할 서브넷 ID 목록"
  type        = list(string)
}

variable "vpc_id" {
  description = "타겟그룹·NLB SG 가 속할 VPC ID"
  type        = string
}

variable "vpc_cidr" {
  description = "NLB 리스너 인바운드/타겟 egress 허용 CIDR (VPC Link ENI 가 VPC 내부)"
  type        = string
}

# 서비스명 → 리스너 포트. NLB(L4)는 경로 라우팅 불가 → 서비스별 포트로 분리
variable "services" {
  description = "외부 노출 서비스 맵 (예: { auth = { listener_port = 8001 } })"
  type = map(object({
    listener_port = number
  }))
  default = {}
}

variable "target_port" {
  description = "파드 수신 포트 (타겟그룹 port + 헬스체크 traffic-port)"
  type        = number
  default     = 8000
}

variable "health_check_path" {
  description = "타겟그룹 HTTP 헬스체크 경로"
  type        = string
  default     = "/readyz"
}

variable "enable_deletion_protection" {
  description = "NLB 삭제 방지 활성화 여부"
  type        = bool
  default     = false
}

# REST VPC Link 트래픽은 VPC CIDR 밖에서 유입 → 기본 0.0.0.0/0. NLB 는 internal 이라 인터넷 비노출
variable "listener_ingress_cidrs" {
  description = "NLB 리스너 인바운드 허용 CIDR (API GW VPC Link 는 VPC CIDR 밖 PrivateLink IP 라 기본 전체 허용; internal NLB)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# cross-zone 과 zonal shift 는 AWS 상 상호 배타 — 둘 중 하나만 true (main.tf precondition 으로 강제)
variable "enable_cross_zone_load_balancing" {
  description = "NLB cross-zone 로드밸런싱. 타겟이 단일 AZ 에 몰려도 모든 AZ 노드가 라우팅(블랙홀 방지). zonal shift 와 동시 사용 불가"
  type        = bool
  default     = true
}

variable "enable_zonal_shift" {
  description = "NLB Zonal Shift(AZ 격리 전환). cross-zone 과 동시 사용 불가"
  type        = bool
  default     = false
}
