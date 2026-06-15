output "http_service_name" {
  value = kubernetes_service_v1.http.metadata[0].name
}

output "grpc_service_name" {
  value = var.grpc_enabled ? kubernetes_service_v1.grpc[0].metadata[0].name : ""
}

output "service_account_name" {
  value = kubernetes_service_account_v1.this.metadata[0].name
}
