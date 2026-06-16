# ===== 공통 =====

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev | prod)"
  type        = string
}

# ===== EKS =====

variable "eks_cluster_name" {
  description = "EKS cluster name to deploy Prometheus"
  type        = string
  default     = ""
}

# ===== Prometheus =====

variable "prometheus_namespace" {
  description = "Kubernetes namespace for Prometheus"
  type        = string
  default     = "monitoring"
}

variable "prometheus_chart_version" {
  description = "Prometheus Helm chart version"
  type        = string
  default     = "25.27.0"
}

variable "retention_days" {
  description = "Prometheus data retention period in days"
  type        = number
  default     = 15
}