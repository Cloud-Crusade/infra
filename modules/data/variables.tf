# ================== 공통 ==================
variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

# rds·elasticache 공용 — 사설 서브넷 배치
variable "subnet_ids" {
  type = list(string)
}

# ================== rds ==================
variable "availability_zones" {
  type = list(string)
}

variable "rds_sg_id" {
  type = string
}

# db_name·db_username·db_password 는 secrets_manager 도 사용(롤·크리덴셜 시크릿)
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

variable "db_instance_class" {
  type = string
}

variable "db_engine_version" {
  type = string
}

variable "db_allocated_storage" {
  type = number
}

# ================== elasticache ==================
variable "cache_sg_id" {
  type = string
}

# ================== secrets_manager ==================
variable "authorization_secret_value" {
  type      = string
  sensitive = true
}

variable "reservation_private_key_value" {
  type      = string
  sensitive = true
}

variable "captcha_hmac_secret_value" {
  type      = string
  sensitive = true
}
