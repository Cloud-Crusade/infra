# ===== Prometheus Helm 배포 =====

resource "helm_release" "prometheus" {
  count = var.eks_cluster_name != "" ? 1 : 0

  name             = "${var.project_name}-${var.environment}-prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "prometheus"
  version          = var.prometheus_chart_version
  namespace        = var.prometheus_namespace
  create_namespace = true

  set {
    name  = "server.retention"
    value = "${var.retention_days}d"
  }

  set {
    name  = "server.global.scrape_interval"
    value = "15s"
  }

  # DaemonSet 방식으로 각 노드에 배포
  set {
    name  = "nodeExporter.enabled"
    value = "true"
  }

  set {
    name  = "alertmanager.enabled"
    value = "false"
  }
}

module "prometheus" {
  source = "../../modules/prometheus"

  project_name = var.project_name
  environment  = var.environment

  # EKS 머지 후 아래 주석 해제
  # eks_cluster_name = module.eks.cluster_name
  eks_cluster_name = ""
}