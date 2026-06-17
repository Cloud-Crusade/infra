# ================== eks (provider 배선·SG·워크로드 노출) ==================
output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_ca_data" {
  value = module.eks.cluster_ca_data
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_security_group_id" {
  value = module.eks.cluster_security_group_id
}

output "ticketing_namespace" {
  value = module.workloads.ticketing_namespace
}

output "ticketing_http_service_names" {
  value = module.workloads.ticketing_http_service_names
}

# nlb_binding(shared) 의 순서 의존 핸들 — 컨트롤러 이후 생성·이전 삭제 보장용
output "aws_lb_controller_role_arn" {
  description = "ALB 컨트롤러 IRSA Role ARN (소비측 nlb_binding 순서 의존)"
  value       = module.aws_lb_controller.role_arn
}
