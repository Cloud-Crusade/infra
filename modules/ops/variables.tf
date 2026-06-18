# ================== 공통 ==================
variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

# ================== network / sg ==================
variable "public_subnet_ids" {
  type = list(string)
}

variable "vpc_id" {
  type = string
}

variable "bastion_sg_id" {
  type = string
}

variable "eks_sg_id" {
  description = "test_service 가 클러스터 워크로드(Redis 등) 접근용으로 부착하는 eks SG"
  type        = string
}

variable "allowed_ssh_cidrs" {
  type = list(string)
}

# ================== bastion ==================
variable "bastion_instance_type" {
  type = string
}

# ================== test_ec2 백엔드 주입(data·async·시크릿·db) ==================
variable "rds_primary_endpoint" {
  type = string
}

variable "rds_primary_replica_endpoint" {
  type = string
}

variable "rds_reservation_endpoint" {
  type = string
}

variable "rds_reservation_replica_endpoint" {
  type = string
}

variable "redis_main_endpoint" {
  type = string
}

variable "sqs_queue_url" {
  type = string
}

variable "sqs_queue_arn" {
  type = string
}

variable "jwt_secret" {
  type      = string
  sensitive = true
}

variable "captcha_hmac_secret" {
  type      = string
  sensitive = true
}

variable "captcha_enabled" {
  type = bool
}

variable "db_name" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}
