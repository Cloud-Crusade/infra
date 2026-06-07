output "main_cache_endpoint" {
  value       = aws_elasticache_replication_group.main_service_cache.primary_endpoint_address
  description = "Valkey 엔드포인트 주소"
}

output "leaky_bucket_cache_endpoint" {
  value       = aws_elasticache_replication_group.leaky_bucket_cache.primary_endpoint_address
  description = "Redis 엔드포인트 주소"
}