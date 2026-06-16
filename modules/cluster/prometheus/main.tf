# ===== Prometheus Helm 배포 =====

resource "helm_release" "prometheus" {
  count            = var.eks_cluster_name != "" ? 1 : 0
  name             = "${var.project_name}-${var.environment}-prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "prometheus"
  version          = var.prometheus_chart_version
  namespace        = var.prometheus_namespace
  create_namespace = true

  # 노드그룹 dedicated taint(system·app) 통과 — 컴포넌트/서브차트별 tolerations
  values = [
    <<-YAML
    server:
      retention: "${var.retention_days}d"
      global:
        scrape_interval: "15s"
      tolerations:
        - key: dedicated
          operator: Exists
          effect: NoSchedule
    nodeExporter:
      enabled: true
    alertmanager:
      enabled: false
    prometheus-node-exporter:
      tolerations:
        - key: dedicated
          operator: Exists
          effect: NoSchedule
    kube-state-metrics:
      tolerations:
        - key: dedicated
          operator: Exists
          effect: NoSchedule
    prometheus-pushgateway:
      tolerations:
        - key: dedicated
          operator: Exists
          effect: NoSchedule
    YAML
  ]
}