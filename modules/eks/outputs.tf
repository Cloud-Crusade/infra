output "cluster_name" {
  description = "EKS 클러스터 이름"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "EKS 클러스터 API 서버 엔드포인트"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_version" {
  description = "EKS 클러스터 버전"
  value       = aws_eks_cluster.this.version
}

output "cluster_iam_role_arn" {
  description = "EKS 클러스터 IAM 역할 ARN"
  value       = aws_iam_role.cluster.arn
}
