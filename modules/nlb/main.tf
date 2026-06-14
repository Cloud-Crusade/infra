resource "aws_lb" "this" {
  name               = "main-lb"
  internal           = true
  load_balancer_type = "network"
  subnets            = var.subnet_ids

  enable_deletion_protection = var.enable_detection_protection

  enable_zonal_shift = var.enable_zonal_shift

  tags = {
    Environment = var.environment
  }
}