# ===== Prometheus Helm 배포 =====

resource "helm_release" "prometheus" {
  count            = var.eks_cluster_name != "" ? 1 : 0
  name             = "${var.project_name}-${var.environment}-prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "prometheus"
  version          = var.prometheus_chart_version
  namespace        = var.prometheus_namespace
  create_namespace = true

  # cold-start(EBS CSI·PVC 바인딩) 여유 + 실패 시 고아 릴리스 잔존 방지
  timeout         = 600
  cleanup_on_fail = true

  # 노드그룹 dedicated taint(system·app) 통과 — 컴포넌트/서브차트별 tolerations
  values = [
    <<-YAML
    server:
      retention: "${var.retention_days}d"
      # 부하테스트용 임시 모니터링 — 영속볼륨 미사용(PVC/StorageClass 의존 제거, cold-start 즉시 기동)
      persistentVolume:
        enabled: false
      # bastion(Grafana/k6) 접근용 internal NLB — VPC 내부에서만(source-ranges). 고정 이름으로 런타임 조회
      service:
        type: LoadBalancer
        servicePort: 80
        annotations:
          service.beta.kubernetes.io/aws-load-balancer-type: external
          service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
          service.beta.kubernetes.io/aws-load-balancer-scheme: internal
          service.beta.kubernetes.io/aws-load-balancer-name: ${var.project_name}-${var.environment}-prometheus
          service.beta.kubernetes.io/aws-load-balancer-source-ranges: ${var.vpc_cidr}
      global:
        scrape_interval: "15s"
      # k6 가 메트릭을 remote-write 로 푸시 → Grafana 에서 조회
      extraFlags:
        - web.enable-remote-write-receiver
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