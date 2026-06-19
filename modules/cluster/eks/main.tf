locals {
  cluster_name = "${var.project_name}-${var.environment}-eks"
  # 노드그룹 dedicated taint(system·app) 통과 — 시스템 애드온이 어느 노드에도 스케줄되도록
  addon_tolerations = [{ key = "dedicated", operator = "Exists", effect = "NoSchedule" }]
}

resource "aws_eks_cluster" "this" {
  name     = local.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    security_group_ids      = var.additional_security_group_ids
    endpoint_private_access = var.cluster_endpoint_private_access
    endpoint_public_access  = var.cluster_endpoint_public_access
    public_access_cidrs     = var.cluster_endpoint_public_access_cidrs
  }
  version = var.cluster_version

  enabled_cluster_log_types = var.cluster_enabled_log_types

  # access entry 기반 접근 허용(운영자/CD) — CONFIG_MAP 도 유지(상위호환). 생성자(CD)는 bootstrap admin
  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  # 컨트롤플레인 기동 전 클러스터 정책 연결 보장
  depends_on = [aws_iam_role_policy_attachment.eks_cluster]
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
  node_role_arn   = aws_iam_role.eks_node.arn
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

  # 노드 부트스트랩(클러스터 join·ECR pull) 전 노드 정책 연결 보장
  depends_on = [
    aws_iam_role_policy_attachment.eks_node_worker,
    aws_iam_role_policy_attachment.eks_node_cni,
    aws_iam_role_policy_attachment.eks_node_ecr,
  ]
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
  service_account_role_arn = aws_iam_role.vpc_cni.arn

  # IRSA 정책 연결 후 애드온 적용(aws-node 가 ENI 관리 권한 확보)
  depends_on = [aws_eks_node_group.this, aws_iam_role_policy_attachment.vpc_cni]
}

# DaemonSet(모든 taint tolerate) — 버전만 클러스터(1.31) 호환으로 고정
resource "aws_eks_addon" "kube_proxy" {
  cluster_name  = aws_eks_cluster.this.name
  addon_name    = "kube-proxy"
  addon_version = "v1.31.14-eksbuild.9"

  depends_on = [aws_eks_node_group.this]
}

# Deployment — dedicated taint 통과 toleration 주입(미주입 시 Pending→DEGRADED). 버전은 toleration 스키마 지원 빌드
resource "aws_eks_addon" "coredns" {
  cluster_name  = aws_eks_cluster.this.name
  addon_name    = "coredns"
  addon_version = "v1.11.4-eksbuild.33"

  configuration_values = jsonencode({
    tolerations = local.addon_tolerations
  })

  depends_on = [aws_eks_node_group.this]
}

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = aws_eks_cluster.this.name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.38.1-eksbuild.1"
  service_account_role_arn = aws_iam_role.ebs_csi.arn

  # controller(Deployment)만 taint 차단 대상 — node DaemonSet 은 기본 tolerate
  configuration_values = jsonencode({
    controller = { tolerations = local.addon_tolerations }
  })

  depends_on = [aws_eks_node_group.this, aws_iam_role_policy_attachment.ebs_csi]
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
