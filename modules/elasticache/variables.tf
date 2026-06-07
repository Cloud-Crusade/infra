# A. 기존 네트워크 및 인프라 연동 변수 
variable "subnet_group_name" {
  type        = string
  description = "vpc 모듈에서 생성 및 배출되어 주입되는 ElastiCache 전용 서브넷 그룹 명칭"
}

variable "main_cache_sg_id" {
  type        = string
  description = "security_group 모듈에서 생성되어 주입되는 대기열 확인용 Valkey SG ID"
}

variable "leaky_bucket_sg_id" {
  type        = string
  description = "security_group 모듈에서 생성되어 주입되는 리키 버킷용 Redis OSS SG ID"
}


# B. Main Cache (Valkey 9.0) 사양 설정 변수
variable "main_cache_replication_group_id" {
  type        = string
  default     = "main-cache"
  description = "대기열 확인 및 동시성 제어를 위한 Main Cache의 리소스 식별 ID"
}

variable "main_cache_engine" {
  type        = string
  default     = "valkey"
  description = "Main Cache에 적용할 오픈소스 인메모리 엔진 타입"
}

variable "main_cache_engine_version" {
  type        = string
  default     = "9.0"
  description = "AWS ElastiCache에서 지원하는 최신 Valkey 엔진 버전"
}

variable "main_cache_parameter_group_name" {
  type        = string
  default     = "default.valkey9"
  description = "Valkey 9.0 싱글 노드 아키텍처 전용 AWS 순정 기본 파라미터 그룹 이름"
}

variable "main_cache_node_type" {
  type        = string
  default     = "cache.m6g.large"
  description = "대기열 대량 진입 요청 네트워크 대역폭 처리를 위한 인스턴스 사양"
}

variable "main_cache_port" {
  type        = number
  default     = 6379
  description = "Valkey 서비스 리스닝 포트 번호"
}

variable "main_cache_num_clusters" {
  type        = number
  default     = 1
  description = "단일 마스터 노드 개수"
}


# C. Leaky Bucket용 Cache (Redis OSS 7.1) 사양 설정 변수
variable "leaky_bucket_replication_group_id" {
  type        = string
  default     = "leaky-bucket-cache"
  description = "예약/결제 정합성 보장 큐 역할을 수행할 캐시 인스턴스의 리소스 식별 ID"
}

variable "leaky_bucket_engine" {
  type        = string
  default     = "redis"
  description = "Redis OSS 엔진 타입"
}

variable "leaky_bucket_engine_version" {
  type        = string
  default     = "7.1"
  description = "AWS ElastiCache에서 지원하는 Redis OSS 엔진 버전"
}

variable "leaky_bucket_parameter_group_family" {
  type        = string
  default     = "redis7"
  description = "엔진 제품군 그룹 명칭"
}

variable "leaky_bucket_node_type" {
  type        = string
  default     = "cache.r6g.large"
  description = "메모리 최적화 인스턴스 사양"
}

variable "leaky_bucket_port" {
  type        = number
  default     = 6379
  description = "Redis OSS 서비스 리스닝 포트 번호"
}

variable "leaky_bucket_num_clusters" {
  type        = number
  default     = 1
  description = "단일 마스터 노드로 순서 정합성을 보장하기 위한 독립 노드 개수"
}