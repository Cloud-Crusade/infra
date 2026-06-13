locals {
  name = "${var.project_name}-${var.environment}"
}

resource "aws_api_gateway_rest_api" "this" {
  name = "${local.name}-rest-api"

  # 단일 리전 백엔드 + 같은 리전 ACM 사용 → REGIONAL (EDGE 의 us-east-1 인증서·이중 CloudFront 회피)
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# 예약 토큰(Reservation) RS256 서명 검증 Lambda authorizer
# authorizer 람다가 S3 의 reservation 공개키로 서명 검증(공개키 위치는 authorizer 람다 env)
# - Reservation 헤더 없음 → 403, 서명 무효 → 403, 유효 → 통과
resource "aws_api_gateway_authorizer" "reservation" {
  name            = "${local.name}-reservation-authorizer"
  rest_api_id     = aws_api_gateway_rest_api.this.id
  type            = "REQUEST"
  authorizer_uri  = var.authorizer_lambda_invoke_arn
  identity_source = "method.request.header.Reservation"
}

# Reservation 헤더 없음(identity source 누락 → 기본 401)을 403 으로 매핑
resource "aws_api_gateway_gateway_response" "unauthorized" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  response_type = "UNAUTHORIZED"
  status_code   = "403"
}

# ===== /reservations (Reservation 헤더 필수) =====
resource "aws_api_gateway_resource" "reservations" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "reservations"
}

resource "aws_api_gateway_method" "reservations" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.reservations.id
  http_method   = "ANY"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.reservation.id
}

resource "aws_api_gateway_integration" "reservations" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.reservations.id
  http_method             = aws_api_gateway_method.reservations.http_method
  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  uri                     = "${var.reservation_backend_url}/reservations"
}

# ===== /reservations/{reservation_id} (Reservation 헤더 필수) =====
resource "aws_api_gateway_resource" "reservation_item" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.reservations.id
  path_part   = "{reservation_id}"
}

resource "aws_api_gateway_method" "reservation_item" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.reservation_item.id
  http_method   = "ANY"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.reservation.id
  request_parameters = {
    "method.request.path.reservation_id" = true
  }
}

resource "aws_api_gateway_integration" "reservation_item" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.reservation_item.id
  http_method             = aws_api_gateway_method.reservation_item.http_method
  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  uri                     = "${var.reservation_backend_url}/reservations/{reservation_id}"
  request_parameters = {
    "integration.request.path.reservation_id" = "method.request.path.reservation_id"
  }
}

# ===== /reservations* CORS 프리플라이트 =====
# CUSTOM authorizer(identity=Reservation 헤더)는 프리플라이트(헤더 없음)를 거부 → OPTIONS 는
# authorization=NONE + MOCK 으로 분리해 CORS 헤더만 반환. 실제 메서드는 위 ANY(CUSTOM) 처리.
locals {
  cors_resources = {
    reservations     = aws_api_gateway_resource.reservations.id
    reservation_item = aws_api_gateway_resource.reservation_item.id
  }
}

resource "aws_api_gateway_method" "cors" {
  for_each      = local.cors_resources
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = each.value
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "cors" {
  for_each          = local.cors_resources
  rest_api_id       = aws_api_gateway_rest_api.this.id
  resource_id       = each.value
  http_method       = aws_api_gateway_method.cors[each.key].http_method
  type              = "MOCK"
  request_templates = { "application/json" = "{\"statusCode\": 200}" }
}

resource "aws_api_gateway_method_response" "cors" {
  for_each    = local.cors_resources
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = each.value
  http_method = aws_api_gateway_method.cors[each.key].http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Max-Age"       = true
  }
}

resource "aws_api_gateway_integration_response" "cors" {
  for_each    = local.cors_resources
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = each.value
  http_method = aws_api_gateway_method.cors[each.key].http_method
  status_code = aws_api_gateway_method_response.cors[each.key].status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,DELETE,OPTIONS'"
    "method.response.header.Access-Control-Allow-Headers" = "'Authorization,Reservation,Content-Type'"
    "method.response.header.Access-Control-Max-Age"       = "'600'"
  }
  depends_on = [aws_api_gateway_integration.cors]
}

# ===== /queue/{event_id} → queue Lambda =====
resource "aws_api_gateway_resource" "queue" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "queue"
}

resource "aws_api_gateway_resource" "queue_item" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.queue.id
  path_part   = "{event_id}"
}

resource "aws_api_gateway_method" "queue" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.queue_item.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "queue" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.queue_item.id
  http_method             = aws_api_gateway_method.queue.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = var.queue_lambda_invoke_arn
}

# ===== /captcha/challenge → captcha Lambda (ALTCHA PoW 챌린지 발급, 공개) =====
# captcha Lambda 가 아직 배포(lambda-modules.txt 등록)되지 않았을 수 있어 옵션으로 둔다
resource "aws_api_gateway_resource" "captcha" {
  count       = var.enable_captcha_route ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "captcha"
}

resource "aws_api_gateway_resource" "captcha_challenge" {
  count       = var.enable_captcha_route ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.captcha[0].id
  path_part   = "challenge"
}

resource "aws_api_gateway_method" "captcha_challenge" {
  count         = var.enable_captcha_route ? 1 : 0
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.captcha_challenge[0].id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "captcha_challenge" {
  count                   = var.enable_captcha_route ? 1 : 0
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.captcha_challenge[0].id
  http_method             = aws_api_gateway_method.captcha_challenge[0].http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = var.captcha_lambda_invoke_arn
}

# ===== 그 외 모든 경로(/{proxy+}) → app 백엔드(EKS). Authorization 은 EKS 가 판별 =====
resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy" {
  rest_api_id        = aws_api_gateway_rest_api.this.id
  resource_id        = aws_api_gateway_resource.proxy.id
  http_method        = "ANY"
  authorization      = "NONE"
  request_parameters = { "method.request.path.proxy" = true }
}

resource "aws_api_gateway_integration" "proxy" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.proxy.id
  http_method             = aws_api_gateway_method.proxy.http_method
  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  uri                     = "${var.app_backend_url}/{proxy}"
  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
}

# ===== 배포 + 스테이지 =====
resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  triggers = {
    redeployment = sha1(jsonencode(concat([
      aws_api_gateway_method.reservations.id,
      aws_api_gateway_integration.reservations.id,
      aws_api_gateway_method.reservation_item.id,
      aws_api_gateway_integration.reservation_item.id,
      aws_api_gateway_method.queue.id,
      aws_api_gateway_integration.queue.id,
      aws_api_gateway_method.proxy.id,
      aws_api_gateway_integration.proxy.id,
      aws_api_gateway_authorizer.reservation.id,
      aws_api_gateway_gateway_response.unauthorized.id,
      aws_api_gateway_gateway_response.unauthorized.status_code,
      ],
      values(aws_api_gateway_method.cors)[*].id,
      values(aws_api_gateway_integration.cors)[*].id,
      values(aws_api_gateway_integration_response.cors)[*].status_code,
      var.enable_captcha_route ? [
        aws_api_gateway_method.captcha_challenge[0].id,
        aws_api_gateway_integration.captcha_challenge[0].id,
    ] : [])))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_method.reservations,
    aws_api_gateway_integration.reservations,
    aws_api_gateway_method.reservation_item,
    aws_api_gateway_integration.reservation_item,
    aws_api_gateway_method.cors,
    aws_api_gateway_integration.cors,
    aws_api_gateway_integration_response.cors,
    aws_api_gateway_method.queue,
    aws_api_gateway_integration.queue,
    aws_api_gateway_method.captcha_challenge,
    aws_api_gateway_integration.captcha_challenge,
    aws_api_gateway_method.proxy,
    aws_api_gateway_integration.proxy,
    aws_api_gateway_authorizer.reservation,
    aws_api_gateway_gateway_response.unauthorized
  ]
}

resource "aws_api_gateway_stage" "this" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id
  stage_name    = var.environment
}

# 게이트웨이 → queue Lambda invoke 권한 (Lambda 자체는 외부 생성)
resource "aws_lambda_permission" "queue" {
  statement_id  = "AllowApiGatewayInvokeQueue"
  action        = "lambda:InvokeFunction"
  function_name = var.queue_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*/queue/*"
}

# 게이트웨이 → captcha Lambda invoke 권한
resource "aws_lambda_permission" "captcha" {
  count         = var.enable_captcha_route ? 1 : 0
  statement_id  = "AllowApiGatewayInvokeCaptcha"
  action        = "lambda:InvokeFunction"
  function_name = var.captcha_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*/captcha/challenge"
}

# 게이트웨이 → authorizer Lambda invoke 권한
resource "aws_lambda_permission" "authorizer" {
  statement_id  = "AllowApiGatewayInvokeAuthorizer"
  action        = "lambda:InvokeFunction"
  function_name = var.authorizer_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/authorizers/${aws_api_gateway_authorizer.reservation.id}"
}

# ===== 커스텀 도메인 (api.<domain>) — REGIONAL + ACM(DNS 검증) =====
resource "aws_acm_certificate" "api" {
  domain_name       = var.api_domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# ACM DNS 검증 레코드 — 기존 호스팅 영역에 생성
resource "aws_route53_record" "api_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.api.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id         = var.route53_zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "api" {
  certificate_arn         = aws_acm_certificate.api.arn
  validation_record_fqdns = [for r in aws_route53_record.api_cert_validation : r.fqdn]
}

resource "aws_api_gateway_domain_name" "api" {
  domain_name              = var.api_domain_name
  regional_certificate_arn = aws_acm_certificate_validation.api.certificate_arn

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# 커스텀 도메인 → 스테이지 매핑 (api.<domain>/ → stage 루트)
resource "aws_api_gateway_base_path_mapping" "api" {
  api_id      = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_stage.this.stage_name
  domain_name = aws_api_gateway_domain_name.api.domain_name
}
