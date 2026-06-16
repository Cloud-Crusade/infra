variable "namespace" {
  description = "metrics-server 배포 네임스페이스"
  type        = string
  default     = "kube-system"
}

# chart 3.12.2 = appVersion v0.7.2
variable "chart_version" {
  description = "metrics-server Helm 차트 버전"
  type        = string
  default     = "3.12.2"
}
