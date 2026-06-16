# metrics-server — HPA(CPU/메모리) 동작에 필요한 리소스 메트릭 제공.
# EKS 는 kubelet 서빙 인증서가 클러스터 CA 로 유효해 추가 플래그(--kubelet-insecure-tls) 불필요 → 기본값 설치.
resource "helm_release" "this" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = var.chart_version
  namespace  = var.namespace

  # 노드그룹 dedicated taint(system·app) 통과
  values = [yamlencode({
    tolerations = [{ key = "dedicated", operator = "Exists", effect = "NoSchedule" }]
  })]
}
