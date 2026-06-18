variable "project_name" {
  description = "프로젝트 이름 (리소스 네이밍)"
  type        = string
}

variable "environment" {
  description = "배포 환경 (dev | prod)"
  type        = string
}

variable "cluster_name" {
  description = "대상 EKS 클러스터 이름 (autoDiscovery + ASG 태그 스코프)"
  type        = string
}

variable "region" {
  description = "AWS 리전 (CA awsRegion)"
  type        = string
}

variable "oidc_provider_arn" {
  description = "EKS OIDC Provider ARN (IRSA)"
  type        = string
}

variable "oidc_provider_url" {
  description = "EKS OIDC Issuer URL (https:// 포함 가능 — 모듈 내부에서 제거)"
  type        = string
}

variable "namespace" {
  description = "CA 배포 네임스페이스"
  type        = string
  default     = "kube-system"
}

variable "service_account_name" {
  description = "CA ServiceAccount 이름 (IRSA sub 조건과 일치)"
  type        = string
  default     = "cluster-autoscaler"
}

# CA 는 클러스터 k8s 마이너와 정합 권장(CA vX.Y ↔ k8s 1.Y). 차트 appVersion 이 곧 CA 버전 →
# 클러스터 k8s 마이너에 맞는 차트 버전을 지정한다(기본 9.57.0 = appVersion 1.35.0).
variable "chart_version" {
  description = "cluster-autoscaler Helm 차트 버전 (클러스터 k8s 마이너에 맞춤)"
  type        = string
  default     = "9.57.0"
}
