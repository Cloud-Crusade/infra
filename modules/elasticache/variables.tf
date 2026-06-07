# 기존 네트워크 및 인프라 연동 변수 
variable "subnet_group_name" {
  type        = string
  description = "VPC ElastiCache 서브넷 그룹 이름"
}

variable "main_cache_sg_id" {
  type        = string
  description = "Main Cache용 보안 그룹 ID"
}

variable "leaky_bucket_sg_id" {
  type        = string
  description = "Leaky Bucket용 보안 그룹 ID"
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


# Leaky Bucket용 Cache (Redis OSS 7.1) 사양 설정 변수
variable "leaky_bucket_replication_group_id" {
  type        = string
  description = "예약/결제 리소스 식별 ID"
}

variable "leaky_bucket_engine" {
  type        = string
  description = "Redis OSS 엔진 타입"
}

variable "leaky_bucket_engine_version" {
  type        = string
  description = "Redis OSS 엔진 버전"
}

variable "leaky_bucket_parameter_group_family" {
  type        = string
  description = "엔진 제품군 그룹 명칭"
}

variable "leaky_bucket_node_type" {
  type        = string
  description = "인스턴스 사양"
}

variable "leaky_bucket_port" {
  type        = number
  description = "리스닝 포트 번호"
}

variable "leaky_bucket_num_clusters" {
  type        = number
  description = "독립 노드 개수"
}