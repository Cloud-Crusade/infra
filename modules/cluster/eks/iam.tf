# EKS IAM — 클러스터/노드 롤과 IRSA(vpc-cni·ebs-csi). IRSA 는 in-module OIDC 직접 참조(chicken-egg 제거)
locals {
  oidc_sub = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
}

# ================== 클러스터 롤 ==================
resource "aws_iam_role" "eks_cluster" {
  name = "${var.project_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# ================== 노드 롤 ==================
resource "aws_iam_role" "eks_node" {
  name = "${var.project_name}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_node_worker" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node.name
}

resource "aws_iam_role_policy_attachment" "eks_node_cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node.name
}

resource "aws_iam_role_policy_attachment" "eks_node_ecr" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node.name
}

# 노드 → ElastiCache(IAM 인증) 접근
resource "aws_iam_policy" "eks_elasticache" {
  name        = "${var.project_name}-eks-elasticache-policy"
  description = "EKS node minimum policy for ElastiCache access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "elasticache:Connect",
        "elasticache:DescribeCacheClusters",
        "elasticache:DescribeReplicationGroups"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_node_elasticache" {
  policy_arn = aws_iam_policy.eks_elasticache.arn
  role       = aws_iam_role.eks_node.name
}

# ================== vpc-cni IRSA (kube-system/aws-node) ==================
resource "aws_iam_role" "vpc_cni" {
  name = "${var.project_name}-vpc-cni-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.eks.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = { StringEquals = { (local.oidc_sub) = "system:serviceaccount:kube-system:aws-node" } }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "vpc_cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.vpc_cni.name
}

# ================== ebs-csi IRSA (kube-system/ebs-csi-controller-sa) ==================
resource "aws_iam_role" "ebs_csi" {
  name = "${var.project_name}-ebs-csi-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.eks.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = { StringEquals = { (local.oidc_sub) = "system:serviceaccount:kube-system:ebs-csi-controller-sa" } }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi.name
}

# ================== Container Insights IRSA (amazon-cloudwatch/cloudwatch-agent) ==================
# CloudWatch agent 가 ContainerInsights 메트릭·로그를 전송할 권한(CloudWatchAgentServerPolicy).
# 애드온이 service_account_role_arn 으로 cloudwatch-agent SA 에 이 롤을 어노테이션.
resource "aws_iam_role" "cloudwatch_agent" {
  count = var.enable_container_insights ? 1 : 0
  name  = "${var.project_name}-cw-agent-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.eks.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = { StringEquals = { (local.oidc_sub) = "system:serviceaccount:amazon-cloudwatch:cloudwatch-agent" } }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  count      = var.enable_container_insights ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.cloudwatch_agent[0].name
}
