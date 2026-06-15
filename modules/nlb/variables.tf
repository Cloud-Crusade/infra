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

variable "enable_detection_protection" {
  description = "NLB 삭제 방지 활성화 여부"
  type        = bool
  default     = false
}

variable "enable_zonal_shift" {
  description = "가용 영역 전환(Zonal Shift) 활성화 여부"
  type        = bool
  default     = true
}
