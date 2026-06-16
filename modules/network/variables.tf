# ================== 공통 ==================
variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

# ================== vpc ==================
variable "vpc_cidr" {
  type = string
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "availability_zones" {
  type = list(string)
}

variable "enable_nat_gateway" {
  type    = bool
  default = false
}

variable "enable_secretsmanager_endpoint" {
  type    = bool
  default = false
}
