locals {
  cluster_name = "${var.project_name}-${var.environment}-eks"
}

resource "aws_eks_cluster" "this" {
  name = local.cluster_name
  role_arn = var.cluster_role_arn

  vpc_config {
    subnet_ids = var.private_subnet_ids
    security_group_ids = var.additional_security_group_ids
    endpoint_private_access = var.cluster_endpoint_private_access
    endpoint_public_access = var.cluster_endpoint_public_access
  }
  version = var.cluster_version

  enabled_cluster_log_types = var.cluster_enabled_log_types

  depends_on = [module.iam]
}

data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_cetificate.eks_oidc.certificates[0].sha1_fingerprint]
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

# system 노드 그룹
resource "aws_eks_node_group" "system" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${local.cluster_name}-system-ng"
  node_role_arn = var.node_role_arn
  subnet_ids = var.subnet_ids

  instance_types = ["t3.small"]
  ami_type = "AL2_x86_64"

  scaling_config {
    desired_size = 1
    max_size = 2
    min_size = 1
  }

  update_config {
    max_unavailable = 1
  }

    taint {
    key = "dedicated"
    value = "system"
    effect = "NO_SCHEDULE"
  }

  labels = {
    role = "system"
  }

  depends_on = [module.iam]
}

# app 노드 그룹 — 애플리케이션 워크로드 전용
resource "aws_eks_node_group" "app" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${local.cluster_name}-app-ng"
  node_role_arn = var.node_role_arn
  subnet_ids = var.subnet_ids

  capacity_type = "SPOT"
  instance_types = ["t3.small", "t3.micro"]
  ami_type = "AL2023_x86_64_STANDARD"

  scaling_config {
    desired_size = 1
    max_size = 2
    min_size = 1
  }

  update_config {
    max_unavailable = 1
  }

  taint {
    key = "dedicated"
    value = "app"
    effect = "NO_SCHEDULE"
  }

  labels = {
    role = "app"
  }

  depends_on = [module.iam]
}

# EKS 애드온
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "vpc-cni"
  addon_version = "v1.18.3-eksbuild.1"
  service_account_role_arn = var.vpc_cni_role_arn

  depends_on = [aws_eks_node_group.system, aws_eks_node_group.app]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "kube-proxy"
  addon_version = "v1.32.0-eksbuild.2"

  depends_on = [aws_eks_node_group.system, aws_eks_node_group.app]
}

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "coredns"
  addon_version = "v1.11.4-eksbuild.2"

  depends_on = [aws_eks_node_group.system, aws_eks_node_group.app]
}

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "aws-ebs-csi-driver"
  addon_version = "v1.38.1-eksbuild.1"
  service_account_role_arn = var.ebs_csi_role_arn

  depends_on = [aws_eks_node_group.system, aws_eks_node_group.app]
}

# 7. 클러스터 접근 제어

resource "aws_eks_access_entry" "this" {
  for_each = { for e in var.access_entries : e.principal_arn => e }

  cluster_name = aws_eks_cluster.this.name
  principal_arn = each.value.principal_arn
  kubernetes_groups = each.value.kubernetes_groups
  type = each.value.type
}

resource "aws_eks_access_policy_association" "this" {
  for_each = { for e in var.access_entries : e.principal_arn => e if e.policy_arn != null }

  cluster_name = aws_eks_cluster.this.name
  principal_arn = each.value.principal_arn

  policy_arn = each.value.policy_arn

  access_scope {
    type = "cluster"
  }
}
