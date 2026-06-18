module "rds" {
  source = "./rds"

  project_name           = var.project_name
  environment            = var.environment
  db_name                = var.db_name
  db_username            = var.db_username
  db_password            = var.db_password
  instance_class         = var.db_instance_class
  engine_version         = var.db_engine_version
  allocated_storage      = var.db_allocated_storage
  vpc_security_group_ids = [var.rds_sg_id]
  azs                    = var.availability_zones
  subnet_ids             = var.subnet_ids
}

module "rds_proxy" {
  source = "./rds_proxy"

  project_name = var.project_name
  environment  = var.environment
  proxy_sg_id  = var.rds_proxy_sg_id
  subnet_ids   = var.subnet_ids

  db_secret_arn             = module.secrets_manager.rds_credentials_secret_arn
  core_db_identifier        = module.rds.primary_identifier
  reservation_db_identifier = module.rds.reservation_identifier
}

module "elasticache" {
  source            = "./elasticache"
  subnet_group_name = "${var.project_name}-${var.environment}-cache"
  subnet_ids        = var.subnet_ids

  main_cache_replication_group_id = "${var.project_name}-${var.environment}-main-cache"
  main_cache_engine               = "valkey"
  main_cache_engine_version       = "8.0"
  main_cache_parameter_group_name = "default.valkey8"
  main_cache_node_type            = "cache.t3.micro"
  main_cache_port                 = 6379
  main_cache_num_clusters         = 1
  main_cache_sg_id                = var.cache_sg_id

  waiting_room_replication_group_id   = "${var.project_name}-${var.environment}-waiting-room"
  waiting_room_engine                 = "redis"
  waiting_room_engine_version         = "7.1"
  waiting_room_parameter_group_family = "redis7"
  waiting_room_node_type              = "cache.t3.micro"
  waiting_room_port                   = 6379
  waiting_room_num_clusters           = 1
  waiting_room_sg_id                  = var.cache_sg_id

  blacklist_replication_group_id   = "${var.project_name}-${var.environment}-blacklist"
  blacklist_engine                 = "redis"
  blacklist_engine_version         = "7.1"
  blacklist_parameter_group_family = "redis7"
  blacklist_node_type              = "cache.t3.micro"
  blacklist_port                   = 6379
  blacklist_num_clusters           = 1
  blacklist_sg_id                  = var.cache_sg_id
}

module "secrets_manager" {
  source = "./secrets_manager"

  project_name                  = var.project_name
  environment                   = var.environment
  authorization_secret_value    = var.authorization_secret_value
  reservation_private_key_value = var.reservation_private_key_value
  rds_username                  = var.db_username
  rds_password                  = var.db_password
  core_writer_endpoint          = module.rds_proxy.core_proxy_endpoint
  reservation_writer_endpoint   = module.rds_proxy.reservation_proxy_endpoint
  captcha_hmac_secret_value     = var.captcha_hmac_secret_value
}
