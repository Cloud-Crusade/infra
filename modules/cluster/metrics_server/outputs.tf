output "helm_release_name" {
  description = "metrics-server Helm 릴리스 이름"
  value       = helm_release.this.name
}
