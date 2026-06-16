locals {
  cluster_name = "${var.project_name}-${var.environment}-eks"
}

resource "aws_eks_cluster" "this" {
  name     = local.cluster_name
  role_arn = var.cluster_role_arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    security_group_ids      = var.additional_security_group_ids
    endpoint_private_access = var.cluster_endpoint_private_access
    endpoint_public_access  = var.cluster_endpoint_public_access
    public_access_cidrs     = var.cluster_endpoint_public_access_cidrs
  }
  version = var.cluster_version

  enabled_cluster_log_types = var.cluster_enabled_log_types
}

data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

# 노드 그룹 — system(전용 워크로드)·app(애플리케이션 전용). taint value·label role 은 키와 동일
locals {
  node_groups = {
    system = {
      capacity_type  = var.system_ng_capacity_type
      instance_types = var.system_ng_instance_types
      disk_size      = var.system_ng_disk_size
      desired_size   = var.system_ng_desired_size
      min_size       = var.system_ng_min_size
      max_size       = var.system_ng_max_size
    }
    app = {
      capacity_type  = var.app_ng_capacity_type
      instance_types = var.app_ng_instance_types
      disk_size      = var.app_ng_disk_size
      desired_size   = var.app_ng_desired_size
      min_size       = var.app_ng_min_size
      max_size       = var.app_ng_max_size
    }
  }
}

resource "aws_eks_node_group" "this" {
  for_each = local.node_groups

  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${local.cluster_name}-${each.key}-ng"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids

  capacity_type  = each.value.capacity_type
  instance_types = each.value.instance_types
  disk_size      = each.value.disk_size
  ami_type       = "AL2023_x86_64_STANDARD"

  scaling_config {
    desired_size = each.value.desired_size
    max_size     = each.value.max_size
    min_size     = each.value.min_size
  }

  update_config {
    max_unavailable = 1
  }

  taint {
    key    = "dedicated"
    value  = each.key
    effect = "NO_SCHEDULE"
  }

  labels = {
    role = each.key
  }
}

# Cluster Autoscaler 자동탐색 태그 — 노드그룹 ASG 에 명시 부착.
# 관리형 노드그룹 자동 부착 여부에 의존하지 않고 보장(같은 값이라 멱등 — 자동 부착돼도 충돌 없음).
resource "aws_autoscaling_group_tag" "cluster_autoscaler" {
  for_each = merge([
    for ng in keys(local.node_groups) : {
      "${ng}/enabled" = { ng = ng, key = "k8s.io/cluster-autoscaler/enabled", value = "true" }
      "${ng}/owned"   = { ng = ng, key = "k8s.io/cluster-autoscaler/${local.cluster_name}", value = "owned" }
    }
  ]...)

  autoscaling_group_name = aws_eks_node_group.this[each.value.ng].resources[0].autoscaling_groups[0].name

  tag {
    key                 = each.value.key
    value               = each.value.value
    propagate_at_launch = false
  }
}

# EKS 애드온
resource "aws_eks_addon" "vpc_cni" {
  cluster_name             = aws_eks_cluster.this.name
  addon_name               = "vpc-cni"
  addon_version            = "v1.18.3-eksbuild.1"
  service_account_role_arn = var.vpc_cni_role_arn

  depends_on = [aws_eks_node_group.this]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name  = aws_eks_cluster.this.name
  addon_name    = "kube-proxy"
  addon_version = "v1.32.0-eksbuild.2"

  depends_on = [aws_eks_node_group.this]
}

resource "aws_eks_addon" "coredns" {
  cluster_name  = aws_eks_cluster.this.name
  addon_name    = "coredns"
  addon_version = "v1.11.4-eksbuild.2"

  depends_on = [aws_eks_node_group.this]
}

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = aws_eks_cluster.this.name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.38.1-eksbuild.1"
  service_account_role_arn = var.ebs_csi_role_arn

  depends_on = [aws_eks_node_group.this]
}

# 7. 클러스터 접근 제어

resource "aws_eks_access_entry" "this" {
  for_each = { for e in var.access_entries : e.principal_arn => e }

  cluster_name      = aws_eks_cluster.this.name
  principal_arn     = each.value.principal_arn
  kubernetes_groups = each.value.kubernetes_groups
  type              = each.value.type
}

resource "aws_eks_access_policy_association" "this" {
  for_each = { for e in var.access_entries : e.principal_arn => e if e.policy_arn != null }

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value.principal_arn

  policy_arn = each.value.policy_arn

  access_scope {
    type = "cluster"
  }
}
