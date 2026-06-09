
# Main Cache (Valkey 9.0) 사양 설정 변수
variable "main_cache_replication_group_id" {
  type        = string
  default     = "main-cache"
  description = "Main Cache의 AWS 리소스 식별 ID"
}

variable "main_cache_engine" {
  type        = string
  default     = "valkey"
  description = "Main Cache에 적용할 오픈소스 인메모리 엔진 타입 (Valkey 채택)"
}

variable "main_cache_engine_version" {
  type        = string
  default     = "9.0"
  description = "AWS ElastiCache에서 지원하는 Valkey 엔진의 메이저 버전"
}

variable "main_cache_parameter_group_name" {
  type        = string
  default     = "default.valkey9"
  description = "Valkey 9.0 싱글 노드 아키텍처에 매칭되는 AWS 순정 기본 파라미터 그룹 이름"
}

variable "main_cache_node_type" {
  type        = string
  default     = "cache.m6g.large"
  description = "초기 다량의 대기열 진입 요청 및 네트워크 대역폭(Throughput)을 감당하기 사양"
}

variable "main_cache_port" {
  type        = number
  default     = 6379
  description = "Valkey 서비스가 트래픽을 리스닝할 포트 번호 (기본 6379)"
}

variable "main_cache_num_clusters" {
  type        = number
  default     = 1
  description = "단일 마스터 노드 개수"
}

# Leaky Bucket용 Cache (Redis 7.1) 사양 설정 변수
variable "leaky_bucket_replication_group_id" {
  type        = string
  default     = "leaky-bucket-cache"
  description = "캐시 인스턴스의 AWS 리소스 식별 ID"
}

variable "leaky_bucket_engine" {
  type        = string
  default     = "redis"
  description = "Leaky Bucket 큐 시스템 엔진 타입"
}

variable "leaky_bucket_engine_version" {
  type        = string
  default     = "7.1"
  description = "Redis OSS 엔진 버전"
}

variable "leaky_bucket_parameter_group_family" {
  type        = string
  default     = "redis7"
  description = "커스텀 파라미터 그룹 생성을 위한 엔진 제품군 그룹 명칭"
}

variable "leaky_bucket_node_type" {
  type        = string
  default     = "cache.r6g.large"
  description = "메모리 최적화 인스턴스 사양"
}

variable "leaky_bucket_port" {
  type        = number
  default     = 6379
  description = "Redis OSS 서비스가 트래픽을 리스닝할 포트 번호 (기본 6379)"
}

variable "leaky_bucket_num_clusters" {
  type        = number
  default     = 1
  description = "단일 마스터 노드로 작동하여 순서 정합성을 유지하기 위한 독립 노드의 총 개수"
}