variable "name" {
  description = "서비스 이름 (auth|event|reservation|payment)"
  type        = string
}

variable "namespace" {
  type = string
}

variable "image" {
  description = "전체 이미지 레퍼런스 (repo:tag)"
  type        = string
}

variable "replicas" {
  type    = number
  default = 2
}

variable "min_replicas" {
  type    = number
  default = 2
}

variable "max_replicas" {
  type    = number
  default = 10
}

variable "enable_memory_autoscaling" {
  description = "메모리 기반 HPA 활성화 유무"
  type        = bool
  default     = false
}

variable "http_port" {
  type    = number
  default = 8000
}

variable "grpc_enabled" {
  description = "gRPC 서버 보유 여부 (event|reservation) → headless Service 생성"
  type        = bool
  default     = false
}

variable "grpc_port" {
  type    = number
  default = 50051
}

variable "config_map_refs" {
  description = "envFrom 으로 주입할 ConfigMap 이름 목록"
  type        = list(string)
  default     = []
}

variable "secret_refs" {
  description = "envFrom 으로 주입할 Secret 이름 목록"
  type        = list(string)
  default     = []
}

variable "extra_env" {
  description = "서비스별 평문 env (gRPC 클라이언트 타깃 등)"
  type        = map(string)
  default     = {}
}

variable "irsa_role_arn" {
  description = "ServiceAccount 에 부여할 IAM Role ARN (IRSA). 빈 값이면 미부여"
  type        = string
  default     = ""
}

variable "cpu_request" {
  type    = string
  default = "200m"
}

variable "cpu_limit" {
  type    = string
  default = "1000m"
}

variable "memory_request" {
  type    = string
  default = "256Mi"
}

variable "memory_limit" {
  type    = string
  default = "512Mi"
}
