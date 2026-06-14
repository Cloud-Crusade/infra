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
