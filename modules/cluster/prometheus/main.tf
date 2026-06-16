# ===== Prometheus Helm 배포 =====

resource "helm_release" "prometheus" {
  count            = var.eks_cluster_name != "" ? 1 : 0
  name             = "${var.project_name}-${var.environment}-prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "prometheus"
  version          = var.prometheus_chart_version
  namespace        = var.prometheus_namespace
  create_namespace = true

  values = [
    <<-YAML
    server:
      retention: "${var.retention_days}d"
      global:
        scrape_interval: "15s"
    nodeExporter:
      enabled: true
    alertmanager:
      enabled: false
    YAML
  ]
}