resource "aws_lb" "this" {
  name               = "main-lb"
  internal           = true
  load_balancer_type = "network"
  subnets            = var.subnet_ids
  security_groups    = [aws_security_group.nlb.id]

  enable_deletion_protection = var.enable_deletion_protection

  enable_zonal_shift = var.enable_zonal_shift
  # AZ Shift를 위해 필요한 설정
  enable_cross_zone_load_balancing = false

  tags = {
    Environment = var.environment
  }
}

# NLB SG — 리스너 포트 인바운드(VPC Link ENI=VPC 내부), 파드 타겟 포트 egress
# 주의: SG 는 NLB 생성 시에만 최초 부착 가능(SG 보유 NLB 는 이후 in-place 변경 가능하나,
#       SG 없이 생성된 NLB 엔 사후 추가 불가) → 기존 main-lb 가 SG 없이 떠 있으면 이 변경은 교체 유발
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

  target_failover {
    on_deregistration = "no_rebalance"
    on_unhealthy      = "no_rebalance"
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
