# ================== rds (직접 엔드포인트) ==================
output "primary_endpoint" {
  value = module.rds.primary_endpoint
}

output "primary_replica_endpoint" {
  value = module.rds.primary_replica_endpoint
}

output "reservation_endpoint" {
  value = module.rds.reservation_endpoint
}

output "reservation_replica_endpoint" {
  value = module.rds.reservation_replica_endpoint
}

# ================== rds_proxy ==================
output "core_proxy_endpoint" {
  description = "Core DB Proxy 엔드포인트 — Multi-AZ Failover 시 연결 단절 최소화"
  value       = module.rds_proxy.core_proxy_endpoint
}

output "reservation_proxy_endpoint" {
  description = "Reservation DB Proxy 엔드포인트 — Multi-AZ Failover 시 연결 단절 최소화"
  value       = module.rds_proxy.reservation_proxy_endpoint
}

# ================== elasticache ==================
output "main_cache_endpoint" {
  value = module.elasticache.main_cache_endpoint
}

output "main_cache_cluster_id" {
  value = module.elasticache.main_cache_cluster_id
}

output "waiting_room_cache_endpoint" {
  value = module.elasticache.waiting_room_cache_endpoint
}

output "waiting_room_cache_cluster_id" {
  value = module.elasticache.waiting_room_cache_cluster_id
}

# ================== secrets_manager ==================
output "authorization_secret_arn" {
  value = module.secrets_manager.authorization_secret_arn
}

output "reservation_private_key_secret_arn" {
  value = module.secrets_manager.reservation_private_key_secret_arn
}

output "rds_credentials_secret_arn" {
  value = module.secrets_manager.rds_credentials_secret_arn
}
