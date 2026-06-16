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
