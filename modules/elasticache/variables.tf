# 기존 네트워크 및 인프라 연동 변수
variable "subnet_group_name" {
  type        = string
  description = "모듈이 생성할 ElastiCache 서브넷 그룹 이름"
}

variable "subnet_ids" {
  type        = list(string)
  description = "서브넷 그룹에 포함할 프라이빗 서브넷 ID 목록"
}

variable "main_cache_sg_id" {
  type        = string
  description = "Main Cache용 보안 그룹 ID"
}

variable "waiting_room_sg_id" {
  type        = string
  description = "watiting_room 용 보안 그룹 ID"
}


# Main Cache (Valkey 9.0) 사양 설정 변수
variable "main_cache_replication_group_id" {
  type        = string
  description = "대기열 확인 및 동시성 제어를 위한 Main Cache의 리소스 식별 ID"
}

variable "main_cache_engine" {
  type        = string
  description = "Main Cache에 적용할 오픈소스 인메모리 엔진 타입"
}

variable "main_cache_engine_version" {
  type        = string
  description = "최신 Valkey 엔진 버전"
}

variable "main_cache_parameter_group_name" {
  type        = string
  description = "Valkey 9.0 싱글 노드 아키텍처 전용 AWS 순정 기본 파라미터 그룹 이름"
}

variable "main_cache_node_type" {
  type        = string
  description = "인스턴스 사양"
}

variable "main_cache_port" {
  type        = number
  description = "Valkey 서비스 리스닝 포트 번호"
}

variable "main_cache_num_clusters" {
  type        = number
  description = "단일 마스터 노드 개수"
}


variable "waiting_room_replication_group_id" {
  type        = string
  description = "대기열 관리 및 트래픽 제어를 위한 캐시 리소스 식별 ID"
}

variable "waiting_room_engine" {
  type        = string
  description = "Waiting Room 캐시에 사용할 Redis 엔진 타입"
}

variable "waiting_room_engine_version" {
  type        = string
  description = "Redis 엔진 버전"
}

variable "waiting_room_parameter_group_family" {
  type        = string
  description = "Redis 파라미터 그룹 패밀리"
}

variable "waiting_room_node_type" {
  type        = string
  description = "Waiting Room 캐시 인스턴스 사양"
}

variable "waiting_room_port" {
  type        = number
  description = "Waiting Room 캐시 서비스 포트 번호"
}

variable "waiting_room_num_clusters" {
  type        = number
  description = "Waiting Room 캐시 노드 개수"
}