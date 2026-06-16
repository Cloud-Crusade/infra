# 관측성 — 공유 SNS + 전 서비스 알람/대시보드
module "cloudwatch" {
  source = "./cloudwatch"

  project_name = var.project_name
  environment  = var.environment
  alarm_email  = var.alarm_email

  rds_instance_ids           = var.rds_instance_ids
  lambda_function_names      = var.lambda_function_names
  cloudfront_distribution_id = var.cloudfront_distribution_id
  elasticache_cluster_ids    = var.elasticache_cluster_ids
  sqs_queue_names            = var.sqs_queue_names

  # EKS/APIGW 알람은 "" 게이팅으로 미활성(활성화는 별도 PR — 리소스 추가)
  eks_cluster_name = var.eks_cluster_name
  api_gateway_name = var.api_gateway_name
}

# 도메인 SG 객체 — eks/rds/cache/lambda/bastion. network 에만 의존(도메인 출력 비참조) → 도메인이 선행 소비
module "security_group" {
  source = "./security_group"

  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = var.vpc_id
  vpc_cidr          = var.vpc_cidr
  allowed_ssh_cidrs = var.allowed_ssh_cidrs
}

# SM 엔드포인트 인바운드(443) — 실제 SM 접근이 필요한 lambda SG 만 허용(최소권한, 모듈 순환 회피)
resource "aws_security_group_rule" "sm_endpoint_from_lambda" {
  type                     = "ingress"
  security_group_id        = var.secretsmanager_endpoint_security_group_id
  source_security_group_id = module.security_group.lambda_sg_id
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  description              = "SM endpoint inbound from lambda SG"
}

# NLB(ip 타겟) → 파드 수신 포트 — 클러스터 SG(관리형 노드그룹·파드 ENI)에 인바운드 허용
resource "aws_security_group_rule" "pods_from_nlb" {
  type                     = "ingress"
  security_group_id        = var.cluster_security_group_id
  source_security_group_id = var.nlb_sg_id
  from_port                = var.ticketing_http_port
  to_port                  = var.ticketing_http_port
  protocol                 = "tcp"
  description              = "ticketing pods from NLB"
}

# NLB 타겟그룹(ip) ↔ 파드 IP 바인딩 — AWS LB Controller 가 ticketing-<svc> 서비스의
# ready 엔드포인트(파드 IP)를 타겟그룹에 등록/해제. NLB ↔ EKS 워크로드 연결의 마지막 고리.
#
# kubernetes_manifest 는 plan 시 클러스터+CRD(TargetGroupBinding) 접속이 필요하므로
# enable_nlb_binding 으로 게이팅 — clean-room plan 에선 0개, 컨트롤러 설치 후 2단계 apply 로 활성화.
# spec.networking 미지정 → 컨트롤러가 SG 를 건드리지 않음(NLB→파드 인바운드는 pods_from_nlb 로 수동 관리).
resource "kubernetes_manifest" "nlb_binding" {
  for_each = var.enable_nlb_binding ? var.service_targets : {}

  manifest = {
    apiVersion = "elbv2.k8s.aws/v1beta1"
    kind       = "TargetGroupBinding"
    metadata = {
      name      = "ticketing-${each.key}"
      namespace = var.ticketing_namespace
    }
    spec = {
      targetGroupARN = each.value.target_group_arn
      targetType     = "ip"
      serviceRef = {
        name = var.ticketing_http_service_names[each.key]
        port = var.ticketing_http_port
      }
    }
  }
}
