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

# chart 9.57.0 (appVersion 1.35.0). CA 이미지는 클러스터 k8s 마이너와 정합 권장.
variable "chart_version" {
  description = "cluster-autoscaler Helm 차트 버전"
  type        = string
  default     = "9.57.0"
}

# 비우면 차트 기본 이미지 사용. 엄격한 버전 정합이 필요하면 클러스터 k8s 마이너에 맞는 태그(예: v1.32.0) 지정
variable "image_tag" {
  description = "CA 이미지 태그 오버라이드 (빈 값이면 차트 기본)"
  type        = string
  default     = ""
}
