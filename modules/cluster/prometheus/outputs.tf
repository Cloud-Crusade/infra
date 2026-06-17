#===== Prometheus =====

output "prometheus_namespace" {
  description = "Kubernetes namespace where Prometheus is deployed"
  value       = var.prometheus_namespace
}

output "prometheus_release_name" {
  description = "Helm release name for Prometheus"
  value       = length(helm_release.prometheus) > 0 ? helm_release.prometheus[0].name : ""
}