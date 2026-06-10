output "main_cache_endpoint" {
  description = "Main 캐시 엔드포인트"
  value       = aws_elasticache_replication_group.main_cache.primary_endpoint_address
}

output "waiting_room_cache_endpoint" {
  description = "Waiting Room 캐시 엔드포인트"
  value       = aws_elasticache_replication_group.waiting_room_cache.primary_endpoint_address
}

output "main_cache_cluster_id" {
  description = "Main cache replication group ID"
  value       = aws_elasticache_replication_group.main_cache.replication_group_id
}

output "waiting_room_cache_cluster_id" {
  description = "Waiting room cache replication group ID"
  value       = aws_elasticache_replication_group.waiting_room_cache.replication_group_id
}