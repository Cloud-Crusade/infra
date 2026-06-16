variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "availability_zones" {
  type = list(string)
}

variable "rds_sg_id" {
  type = string
}

variable "cache_sg_id" {
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

variable "db_instance_class" {
  type = string
}

variable "db_engine_version" {
  type = string
}

variable "db_allocated_storage" {
  type = number
}

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
