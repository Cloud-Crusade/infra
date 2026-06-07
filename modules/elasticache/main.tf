
# 1. Main Cache (대기열 확인 및 Atomic Check 보장용) - Valkey 9.0
resource "aws_elasticache_replication_group" "main_service_cache" {
  replication_group_id = var.main_cache_replication_group_id
  description          = "Main Cache for Virtual Waiting Room Atomic Check"

  engine               = var.main_cache_engine
  engine_version       = var.main_cache_engine_version
  parameter_group_name = var.main_cache_parameter_group_name
  node_type            = var.main_cache_node_type
  port                 = var.main_cache_port

  subnet_group_name  = var.subnet_group_name
  security_group_ids = [var.main_cache_sg_id]

  num_cache_clusters = var.main_cache_num_clusters
}


# 2. Leaky Bucket용 Cache (예약/결제 정합성 보장용) - Redis OSS 7.1
resource "aws_elasticache_parameter_group" "leaky_bucket_params" {
  name   = "${var.leaky_bucket_replication_group_id}-params"
  family = var.leaky_bucket_parameter_group_family

  parameter {
    name  = "maxmemory-policy"
    value = "noeviction"
  }
}

resource "aws_elasticache_replication_group" "leaky_bucket_cache" {
  replication_group_id = var.leaky_bucket_replication_group_id
  description          = "Redis Cache for Reservation Integrity"

  engine               = var.leaky_bucket_engine
  engine_version       = var.leaky_bucket_engine_version
  parameter_group_name = aws_elasticache_parameter_group.leaky_bucket_params.name
  node_type            = var.leaky_bucket_node_type
  port                 = var.leaky_bucket_port

  subnet_group_name  = var.subnet_group_name
  security_group_ids = [var.leaky_bucket_sg_id]

  num_cache_clusters = var.leaky_bucket_num_clusters
}