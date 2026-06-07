output "main_cache_endpoint" {
  description = "main 캐시 엔드포인트"
  value       = aws_elasticache_replication_group.main_cache.primary_endpoint_address
}

output "waiting_room_cache_endpoint" {
  description = "Waiting Room 캐시 엔드포인트"
  value       = aws_elasticache_replication_group.waiting_room_cache.primary_endpoint_address
}