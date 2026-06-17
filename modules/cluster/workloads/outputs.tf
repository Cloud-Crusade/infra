output "ticketing_namespace" {
  value = local.ticketing_namespace
}

output "ticketing_http_service_names" {
  value = { for k, m in module.ticketing_service : k => m.http_service_name }
}

output "ticketing_grpc_service_names" {
  value = { for k, m in module.ticketing_service : k => m.grpc_service_name }
}
