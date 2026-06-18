module "nlb" {
  source = "./nlb"

  project_name = var.project_name
  environment  = var.environment
  subnet_ids   = var.subnet_ids
  vpc_id       = var.vpc_id
  vpc_cidr     = var.vpc_cidr
  target_port  = var.ticketing_http_port

  # AZ Failover: on 이면 zonal shift, off 면 cross-zone (NLB 상 상호 배타)
  enable_cross_zone_load_balancing = !var.enable_az_failover
  enable_zonal_shift               = var.enable_az_failover

  # 4서비스 외부 노출 — 포트로 분리, apigateway 가 경로별로 연결
  services = {
    auth        = { listener_port = 8001 }
    event       = { listener_port = 8002 }
    reservation = { listener_port = 8003 }
    payment     = { listener_port = 8004 }
  }
}

# API Gateway — 백엔드(EKS NLB ↔ test-EC2)는 backend 로 선택, queue 는 ticketing 람다
module "apigateway" {
  source       = "./apigateway"
  project_name = var.project_name
  environment  = var.environment

  backend          = var.api_backend
  test_backend_url = var.test_backend_url

  # 경로 프리픽스 → NLB 리스너 포트(VPC Link). path 는 백엔드 FastAPI 라우터 prefix 와 일치
  nlb_arn      = module.nlb.nlb_arn
  nlb_dns_name = module.nlb.nlb_dns_name
  services = {
    for k, v in module.nlb.service_targets : k => {
      listener_port = v.listener_port
      path          = { auth = "auth", event = "events", reservation = "reservations", payment = "payments" }[k]
    }
  }

  queue_lambda_invoke_arn    = var.lambda_invoke_arns["ticketing"]
  queue_lambda_function_name = var.lambda_function_names["ticketing"]

  # captcha Lambda 가 배포(등록)됐을 때만 라우트 생성 — 미배포 시 plan 실패 방지
  enable_captcha_route         = contains(keys(var.lambda_function_names), "captcha")
  captcha_lambda_invoke_arn    = lookup(var.lambda_invoke_arns, "captcha", "")
  captcha_lambda_function_name = lookup(var.lambda_function_names, "captcha", "")

  authorizer_lambda_invoke_arn    = var.lambda_invoke_arns["authorizer"]
  authorizer_lambda_function_name = var.lambda_function_names["authorizer"]

  api_domain_name = "api.${var.domain_name}"
  route53_zone_id = var.route53_zone_id
}

# Route53 — www → CloudFront(frontend), api → API Gateway(REGIONAL)
module "route53" {
  source = "./route53"

  domain_name     = var.domain_name
  route53_zone_id = var.route53_zone_id

  cloudfront_domain_name = var.cloudfront_domain_name
  cloudfront_zone_id     = var.cloudfront_zone_id

  api_target_dns_name = module.apigateway.domain_regional_target
  api_target_zone_id  = module.apigateway.domain_regional_zone_id
}
