# EKS 클러스터 롤 ARN을 외부에 전달
output "cluster_role_arn" {
  description = "EKS Control Plane IAM Role ARN"
  value       = aws_iam_role.eks_cluster.arn
}

# EKS 노드 그룹 롤 ARN을 외부에 전달
output "ng_role_arn" {
  description = "Node Group EC2 IAM Role ARN"
  value       = aws_iam_role.eks_node.arn
}

# Lambda 롤 ARN을 외부에 전달
output "lambda_role_arn" {
  description = "Lambda 롤 ARN"
  value       = aws_iam_role.lambda.arn
}

# vpc_cni 롤 ARN (IRSA)
# output "vpc_cni_role_arn" {
#   description = "vpc-cni 애드온 IRSA Role ARN"
#   value       = aws_iam_role.vpc_cni.arn
# }

# ebs_csi 롤 ARN (IRSA)
# output "ebs_csi_role_arn" {
#   description = "ebs-csi-driver 애드온 IRSA Role ARN"
#   value       = aws_iam_role.ebs_csi.arn
# }