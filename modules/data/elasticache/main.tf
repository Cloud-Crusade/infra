
# 0. 서브넷 그룹 (프라이빗 서브넷) — 모듈 내부에서 생성
resource "aws_elasticache_subnet_group" "this" {
  name       = var.subnet_group_name
  subnet_ids = var.subnet_ids
}

# 1. Main Cache (대기열 확인 및 Atomic Check 보장용) - Valkey 9.0
resource "aws_elasticache_replication_group" "main_cache" {
  replication_group_id = var.main_cache_replication_group_id
  description          = "Main Cache for Virtual Waiting Room Atomic Check"

  engine               = var.main_cache_engine
  engine_version       = var.main_cache_engine_version
  parameter_group_name = var.main_cache_parameter_group_name
  node_type            = var.main_cache_node_type
  port                 = var.main_cache_port

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = [var.main_cache_sg_id]

  num_cache_clusters = var.main_cache_num_clusters
}



# 2. Waiting Room Cache 
resource "aws_elasticache_parameter_group" "waiting_room_params" {
  name   = "${var.waiting_room_replication_group_id}-params"
  family = var.waiting_room_parameter_group_family

  parameter {
    name  = "maxmemory-policy"
    value = "noeviction"
  }
}

resource "aws_elasticache_replication_group" "waiting_room_cache" {
  replication_group_id = var.waiting_room_replication_group_id
  description          = "Cache for waiting room queue management and traffic control"

  engine               = var.waiting_room_engine
  engine_version       = var.waiting_room_engine_version
  parameter_group_name = aws_elasticache_parameter_group.waiting_room_params.name
  node_type            = var.waiting_room_node_type
  port                 = var.waiting_room_port

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = [var.waiting_room_sg_id]

  num_cache_clusters = var.waiting_room_num_clusters
}

# 3. Blacklist Cache
resource "aws_elasticache_parameter_group" "blacklist_params" {
  name   = "${var.blacklist_replication_group_id}-params"
  family = var.blacklist_parameter_group_family

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }
}

resource "aws_elasticache_replication_group" "blacklist_cache" {
  replication_group_id = var.blacklist_replication_group_id
  description          = "Cache for IP blacklist management"

  engine               = var.blacklist_engine
  engine_version       = var.blacklist_engine_version
  parameter_group_name = aws_elasticache_parameter_group.blacklist_params.name
  node_type            = var.blacklist_node_type
  port                 = var.blacklist_port

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = [var.blacklist_sg_id]

  num_cache_clusters = var.blacklist_num_clusters
}