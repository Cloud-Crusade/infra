output "cluster_name" {
  description = "EKS 클러스터 이름"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "EKS API 서버 엔드포인트"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_ca_data" {
  description = "클러스터 CA 인증서 (base64)"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_version" {
  description = "Kubernetes 버전"
  value       = aws_eks_cluster.this.version
}

output "oidc_provider_arn" {
  description = "OIDC Provider ARN (IRSA에서 사용)"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_issuer_url" {
  description = "OIDC Issuer URL"
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "cluster_security_group_id" {
  description = "EKS 관리 클러스터 보안 그룹 ID (관리형 노드그룹·파드 ENI 에 적용 — NLB→파드 인바운드 대상)"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

# ===== MSA 워크로드 =====
output "ticketing_namespace" {
  description = "ticketing 워크로드 네임스페이스"
  value       = kubernetes_namespace_v1.ticketing.metadata[0].name
}

output "ticketing_http_service_names" {
  description = "서비스명 → 인클러스터 HTTP(ClusterIP) Service 이름 (NLB·내부 DNS 바인딩 대상)"
  value       = { for k, m in module.ticketing_service : k => m.http_service_name }
}

output "ticketing_grpc_service_names" {
  description = "서비스명 → headless gRPC Service 이름 (gRPC 보유 서비스만, 그 외 빈 문자열)"
  value       = { for k, m in module.ticketing_service : k => m.grpc_service_name }
}
