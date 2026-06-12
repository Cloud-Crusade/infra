# ===== 공통 =====

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev | prod)"
  type        = string
}

# ===== SNS =====

variable "alarm_email" {
  description = "Email address to receive CloudWatch alarm notifications"
  type        = string
  default     = ""
}

# ===== RDS =====

variable "rds_instance_ids" {
  description = "List of RDS instance identifiers to monitor"
  type        = list(string)
  default     = []
}

# ===== Lambda =====

variable "lambda_function_names" {
  description = "List of Lambda function names to monitor"
  type        = list(string)
  default     = []
}

# ===== CloudFront =====

variable "cloudfront_distribution_id" {
  description = "CloudFront distribution ID to monitor"
  type        = string
  default     = ""
}

# ===== ElastiCache (틀만 — 모듈 연결 후 활성화) =====

variable "elasticache_cluster_ids" {
  description = "List of ElastiCache cluster IDs to monitor (activate after module connection)"
  type        = list(string)
  default     = []
}

# ===== SQS (틀만 — 모듈 연결 후 활성화) =====

variable "sqs_queue_names" {
  description = "List of SQS queue names to monitor (activate after module connection)"
  type        = list(string)
  default     = []
}

# ===== EKS (틀만 — 모듈 연결 후 활성화) =====

variable "eks_cluster_name" {
  description = "EKS cluster name to monitor (activate after module connection)"
  type        = string
  default     = ""
}

# ===== API Gateway (모듈 연결 후 활성화) =====

variable "api_gateway_name" {
  description = "REST API name to monitor (activate after module connection)"
  type        = string
  default     = ""
}
