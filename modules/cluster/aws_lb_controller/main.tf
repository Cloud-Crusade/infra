locals {
  name     = "${var.project_name}-${var.environment}-alb-controller"
  oidc_url = replace(var.oidc_provider_url, "https://", "")
}

# 컨트롤러 IAM 정책 — kubernetes-sigs/aws-load-balancer-controller v2.11.0 공식 정책(iam_policy.json)
resource "aws_iam_policy" "this" {
  name   = local.name
  policy = file("${path.module}/iam_policy.json")
}

data "aws_iam_policy_document" "assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_url}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account_name}"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = local.name
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}

resource "helm_release" "this" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.chart_version
  namespace  = var.namespace

  # SA 는 차트가 생성하고 IRSA Role 을 어노테이션으로 부착
  values = [yamlencode({
    clusterName = var.cluster_name
    region      = var.region
    vpcId       = var.vpc_id

    enableServiceMutatorWebhook = false
    # 노드그룹 dedicated taint(system·app) 통과
    tolerations = [{ key = "dedicated", operator = "Exists", effect = "NoSchedule" }]
    serviceAccount = {
      create = true
      name   = var.service_account_name
      annotations = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.this.arn
      }
    }
  })]
}
