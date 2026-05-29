variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "environment" {
  description = "배포 환경"
  type        = string
}

variable "cluster_version" {
  description = "EKS 클러스터 버전"
  type        = string
  default     = "1.30"
}

variable "subnet_ids" {
  description = "EKS 클러스터 및 노드 그룹에 사용할 서브넷 ID 목록"
  type        = list(string)
}

variable "endpoint_public_access" {
  description = "EKS API 서버 퍼블릭 엔드포인트 활성화 여부"
  type        = bool
  default     = false
}

variable "node_instance_types" {
  description = "노드 그룹 인스턴스 타입 목록"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "노드 그룹 원하는 노드 수"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "노드 그룹 최소 노드 수"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "노드 그룹 최대 노드 수"
  type        = number
  default     = 4
}
