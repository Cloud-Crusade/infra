# NLB 타겟그룹(ip) ↔ 파드 IP 바인딩 — AWS LB Controller(#133) 가 ticketing-<svc> 서비스의
# ready 엔드포인트(파드 IP)를 해당 타겟그룹에 등록/해제. NLB(#134) ↔ EKS 워크로드 연결의 마지막 고리.
#
# kubernetes_manifest 는 plan 시 클러스터+CRD(TargetGroupBinding) 접속이 필요하므로
# var.enable_nlb_binding 로 게이팅 — clean-room plan 에선 0개, 컨트롤러 설치 후 2단계 apply 로 활성화.
# spec.networking 미지정 → 컨트롤러가 SG 를 건드리지 않음(NLB→파드 인바운드는 pods_from_nlb 규칙으로 수동 관리).
resource "kubernetes_manifest" "nlb_binding" {
  for_each = var.enable_nlb_binding ? module.nlb.service_targets : {}

  manifest = {
    apiVersion = "elbv2.k8s.aws/v1beta1"
    kind       = "TargetGroupBinding"
    metadata = {
      name      = "ticketing-${each.key}"
      namespace = module.eks.ticketing_namespace
    }
    spec = {
      targetGroupARN = each.value.target_group_arn
      targetType     = "ip"
      serviceRef = {
        name = module.eks.ticketing_http_service_names[each.key]
        port = 8000
      }
    }
  }
}
