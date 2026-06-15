resource "aws_lb" "this" {
  name               = "main-lb"
  internal           = true
  load_balancer_type = "network"
  subnets            = var.subnet_ids
  security_groups    = [aws_security_group.nlb.id]

  enable_deletion_protection = var.enable_detection_protection

  enable_zonal_shift = var.enable_zonal_shift

  tags = {
    Environment = var.environment
  }
}

# NLB SG — 리스너 포트 인바운드(VPC Link ENI=VPC 내부), 파드 타겟 포트 egress
# 주의: NLB 의 SG 는 생성 시에만 부착 가능 → 기존 SG 없는 NLB 에 추가하면 교체됨
resource "aws_security_group" "nlb" {
  name        = "${var.project_name}-${var.environment}-nlb-sg"
  description = "ticketing NLB listener ingress / pod egress"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-${var.environment}-nlb-sg"
  }
}

resource "aws_security_group_rule" "nlb_listener_ingress" {
  for_each          = var.services
  type              = "ingress"
  security_group_id = aws_security_group.nlb.id
  from_port         = each.value.listener_port
  to_port           = each.value.listener_port
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  description       = "${each.key} listener from VPC (API GW VPC Link)"
}

resource "aws_security_group_rule" "nlb_target_egress" {
  type              = "egress"
  security_group_id = aws_security_group.nlb.id
  from_port         = var.target_port
  to_port           = var.target_port
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  description       = "NLB to pod target port"
}

# 서비스별 타겟그룹(ip) — LB Controller(#133)의 TargetGroupBinding 이 파드 IP 등록(#135)
resource "aws_lb_target_group" "svc" {
  for_each    = var.services
  name        = "${var.environment}-${each.key}-tg"
  port        = var.target_port
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    protocol            = "HTTP"
    path                = var.health_check_path
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = {
    Environment = var.environment
  }
}

# 서비스별 리스너 — 포트로 서비스 분리, API GW 가 경로별로 해당 포트에 연결(#136)
resource "aws_lb_listener" "svc" {
  for_each          = var.services
  load_balancer_arn = aws_lb.this.arn
  port              = each.value.listener_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.svc[each.key].arn
  }
}
