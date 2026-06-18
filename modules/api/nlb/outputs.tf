output "nlb_arn" {
  description = "NLB ARN"
  value       = aws_lb.this.arn
}

output "nlb_id" {
  description = "NLB ID"
  value       = aws_lb.this.id
}

output "nlb_dns_name" {
  description = "NLB DNS 이름"
  value       = aws_lb.this.dns_name
}

output "nlb_zone_id" {
  description = "NLB Route 53 호스팅 영역 ID"
  value       = aws_lb.this.zone_id
}

output "nlb_sg_id" {
  description = "NLB 보안 그룹 ID (파드 SG 인바운드 소스)"
  value       = aws_security_group.nlb.id
}

output "service_targets" {
  description = "서비스명 → { listener_port, target_group_arn } (TargetGroupBinding·API GW 배선용)"
  value = {
    for k, tg in aws_lb_target_group.svc : k => {
      listener_port    = var.services[k].listener_port
      target_group_arn = tg.arn
    }
  }
}

output "lb_arn_suffix" {
  description = "NLB ARN suffix (CloudWatch LoadBalancer dimension)"
  value       = aws_lb.this.arn_suffix
}

output "target_group_arn_suffixes" {
  description = "서비스명 → 타겟그룹 ARN suffix (CloudWatch TargetGroup dimension)"
  value       = { for k, tg in aws_lb_target_group.svc : k => tg.arn_suffix }
}