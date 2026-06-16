variable "project_name" {
  description = "프로젝트 이름 (리소스 네이밍)"
  type        = string
}

variable "environment" {
  description = "배포 환경 (dev | prod)"
  type        = string
}

variable "cluster_name" {
  description = "대상 EKS 클러스터 이름"
  type        = string
}

variable "region" {
  description = "AWS 리전 (컨트롤러 차트 values)"
  type        = string
}

variable "vpc_id" {
  description = "클러스터 VPC ID (컨트롤러 차트 values)"
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
  description = "컨트롤러 배포 네임스페이스"
  type        = string
  default     = "kube-system"
}

variable "service_account_name" {
  description = "컨트롤러 ServiceAccount 이름 (IRSA sub 조건과 일치)"
  type        = string
  default     = "aws-load-balancer-controller"
}

# chart 1.11.0 = appVersion v2.11.0 (iam_policy.json 도 동일 버전 기준)
variable "chart_version" {
  description = "aws-load-balancer-controller Helm 차트 버전"
  type        = string
  default     = "1.11.0"
}
