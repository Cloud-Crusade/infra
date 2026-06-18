# ================== 공통 ==================
variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

# ================== lambda ==================
variable "lambda_sg_id" {
  type = string
}

variable "vpc_subnet_ids" {
  type = list(string)
}

variable "secrets_extension_layer_arn" {
  type = string
}

# lambda_env 주입값 — data 레이어(RDS/캐시/시크릿)·frontend(cloudfront)·DB 크리덴셜
variable "reservation_endpoint" {
  type = string
}

variable "waiting_room_cache_endpoint" {
  type = string
}

variable "reservation_private_key_secret_arn" {
  type = string
}

variable "authorization_secret_arn" {
  type = string
}

variable "cloudfront_domain_name" {
  type = string
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
