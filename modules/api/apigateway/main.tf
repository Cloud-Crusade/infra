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

# VPC Link — REST API → internal NLB 사설 연결(REST API VPC Link 는 NLB 만 지원). eks 백엔드일 때만 생성
resource "aws_api_gateway_vpc_link" "this" {
  count       = local.use_eks ? 1 : 0
  name        = "${local.name}-vpc-link"
  target_arns = [var.nlb_arn]
}

locals {
  # 백엔드 선택: eks(NLB VPC Link, 서비스별 포트) | test_ec2(단일 nginx 게이트웨이, INTERNET)
  use_eks   = var.backend == "eks"
  conn_type = local.use_eks ? "VPC_LINK" : "INTERNET"
  # vpc_link 는 eks 일 때만 1개 → one() 으로 id 추출(test_ec2 면 0개 → null=connection_id 생략). count=0 시 this[0] 인덱스 에러 회피
  conn_id = one(aws_api_gateway_vpc_link.this[*].id)
  # 서비스명 → 통합 base url. test_ec2 는 nginx 게이트웨이가 경로별 라우팅하므로 전 서비스 동일 host:port
  svc_base = {
    for k, v in var.services : k => local.use_eks ? "http://${var.nlb_dns_name}:${v.listener_port}" : var.test_backend_url
  }

  # 예약은 토큰 게이트 때문에 명시 라우트로 처리 → 제네릭 프록시 대상에서 제외
  proxy_services = { for k, v in var.services : k => v if k != "reservation" }
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

# authorizer 거부 응답. 헤더 누락 → UNAUTHORIZED(403 매핑), 서명무효·만료·불일치 → Deny → ACCESS_DENIED(403).
# 둘 다 CORS 헤더를 실어 브라우저가 4xx 를 읽고 클라이언트가 토큰 정리·재대기열 가능하게 한다.
resource "aws_api_gateway_gateway_response" "unauthorized" {
  rest_api_id         = aws_api_gateway_rest_api.this.id
  response_type       = "UNAUTHORIZED"
  status_code         = "403"
  response_parameters = local.gateway_cors_headers
}

resource "aws_api_gateway_gateway_response" "access_denied" {
  rest_api_id         = aws_api_gateway_rest_api.this.id
  response_type       = "ACCESS_DENIED"
  status_code         = "403"
  response_parameters = local.gateway_cors_headers
}

# ===== /reservations =====
# 대기열 입장 토큰(Reservation)은 스파이크 경로인 예매 진입(POST 생성)에만 게이트한다.
# 확인(GET)·취소(DELETE)는 access 토큰만 필요(백엔드 getCurrentUserId 가 인증) → authorization=NONE 으로 프록시.
resource "aws_api_gateway_resource" "reservations" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "reservations"
}

# POST 생성 — 입장 토큰 게이트
resource "aws_api_gateway_method" "reservations_post" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.reservations.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.reservation.id
}

resource "aws_api_gateway_integration" "reservations_post" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.reservations.id
  http_method             = aws_api_gateway_method.reservations_post.http_method
  type                    = "HTTP_PROXY"
  integration_http_method = "POST"
  connection_type         = local.conn_type
  connection_id           = local.conn_id
  uri                     = "${local.svc_base["reservation"]}/reservations"
}

# GET 목록 — 확인은 access 토큰만(입장 토큰 불필요)
resource "aws_api_gateway_method" "reservations_get" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.reservations.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "reservations_get" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.reservations.id
  http_method             = aws_api_gateway_method.reservations_get.http_method
  type                    = "HTTP_PROXY"
  integration_http_method = "GET"
  connection_type         = local.conn_type
  connection_id           = local.conn_id
  uri                     = "${local.svc_base["reservation"]}/reservations"
}

# ===== /reservations/{reservation_id} — 확인(GET)·취소(DELETE): access 토큰만 =====
resource "aws_api_gateway_resource" "reservation_item" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.reservations.id
  path_part   = "{reservation_id}"
}

resource "aws_api_gateway_method" "reservation_item" {
  for_each      = toset(["GET", "DELETE"])
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.reservation_item.id
  http_method   = each.value
  authorization = "NONE"
  request_parameters = {
    "method.request.path.reservation_id" = true
  }
}

resource "aws_api_gateway_integration" "reservation_item" {
  for_each                = aws_api_gateway_method.reservation_item
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.reservation_item.id
  http_method             = each.value.http_method
  type                    = "HTTP_PROXY"
  integration_http_method = each.value.http_method
  connection_type         = local.conn_type
  connection_id           = local.conn_id
  uri                     = "${local.svc_base["reservation"]}/reservations/{reservation_id}"
  request_parameters = {
    "integration.request.path.reservation_id" = "method.request.path.reservation_id"
  }
}

# ===== /reservations/seats/occupied — 점유 좌석 조회(GET): access 토큰만(입장 토큰 불필요) =====
resource "aws_api_gateway_resource" "seats" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.reservations.id
  path_part   = "seats"
}

resource "aws_api_gateway_resource" "seats_occupied" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.seats.id
  path_part   = "occupied"
}

resource "aws_api_gateway_method" "seats_occupied" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.seats_occupied.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "seats_occupied" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.seats_occupied.id
  http_method             = aws_api_gateway_method.seats_occupied.http_method
  type                    = "HTTP_PROXY"
  integration_http_method = "GET"
  connection_type         = local.conn_type
  connection_id           = local.conn_id
  # HTTP_PROXY 는 쿼리스트링(?event_id=)을 그대로 전달
  uri = "${local.svc_base["reservation"]}/reservations/seats/occupied"
}

# ===== /reservations* CORS 프리플라이트 =====
# 명시 리소스라 OPTIONS 를 직접 정의해야 함. authorization=NONE + MOCK 으로 CORS 헤더만 반환
# (POST 의 CUSTOM authorizer 는 프리플라이트(헤더 없음)를 거부하므로 OPTIONS 를 분리).
locals {
  cors_resources = merge(
    {
      reservations     = aws_api_gateway_resource.reservations.id
      reservation_item = aws_api_gateway_resource.reservation_item.id
      seats_occupied   = aws_api_gateway_resource.seats_occupied.id
    },
    { for k, r in aws_api_gateway_resource.svc_root : "${k}_root" => r.id },
    { for k, r in aws_api_gateway_resource.svc_proxy : "${k}_proxy" => r.id },
    # captcha/challenge 는 공개 GET 이나 브라우저 CORS preflight(OPTIONS) 필요 → 캡차 로드/예매 제출 차단 방지
    var.enable_captcha_route ? { captcha_challenge = aws_api_gateway_resource.captcha_challenge[0].id } : {},
  )
  # 헤더 값을 한 곳에서 정의 → integration_response 와 배포 트리거가 같은 출처 참조(값 변경 시 재배포)
  cors_response_headers = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,PUT,PATCH,DELETE,OPTIONS'"
    "method.response.header.Access-Control-Allow-Headers" = "'Authorization,Reservation,Content-Type,X-Captcha-Token'"
    "method.response.header.Access-Control-Max-Age"       = "'600'"
  }
  # authorizer 거부(4xx) 응답용 CORS 헤더 — 위 값을 gatewayresponse 접두사로 재사용(Max-Age 는 에러응답 불필요라 제외)
  gateway_cors_headers = {
    for key, value in local.cors_response_headers :
    replace(key, "method.response.header.", "gatewayresponse.header.") => value
    if !endswith(key, "Max-Age")
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
  for_each            = local.cors_resources
  rest_api_id         = aws_api_gateway_rest_api.this.id
  resource_id         = each.value
  http_method         = aws_api_gateway_method.cors[each.key].http_method
  status_code         = aws_api_gateway_method_response.cors[each.key].status_code
  response_parameters = local.cors_response_headers
  depends_on          = [aws_api_gateway_integration.cors]
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

# ===== 서비스별 경로(/auth,/events,/payments) → NLB(VPC Link). Authorization 은 백엔드가 판별 =====
# 예약(/reservations)은 토큰 게이트 때문에 위 명시 라우트로 별도 처리. 여기선 나머지 3서비스를 제네릭 프록시로.
# 각 서비스는 루트(/svc)와 하위(/svc/{proxy+}) 두 리소스 — 목록(GET /events)·하위경로(POST /auth/login) 모두 커버.
resource "aws_api_gateway_resource" "svc_root" {
  for_each    = local.proxy_services
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = each.value.path
}

resource "aws_api_gateway_resource" "svc_proxy" {
  for_each    = local.proxy_services
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.svc_root[each.key].id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "svc_root" {
  for_each      = local.proxy_services
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.svc_root[each.key].id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "svc_root" {
  for_each                = local.proxy_services
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.svc_root[each.key].id
  http_method             = aws_api_gateway_method.svc_root[each.key].http_method
  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  connection_type         = local.conn_type
  connection_id           = local.conn_id
  uri                     = "${local.svc_base[each.key]}/${each.value.path}"
}

resource "aws_api_gateway_method" "svc_proxy" {
  for_each           = local.proxy_services
  rest_api_id        = aws_api_gateway_rest_api.this.id
  resource_id        = aws_api_gateway_resource.svc_proxy[each.key].id
  http_method        = "ANY"
  authorization      = "NONE"
  request_parameters = { "method.request.path.proxy" = true }
}

resource "aws_api_gateway_integration" "svc_proxy" {
  for_each                = local.proxy_services
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.svc_proxy[each.key].id
  http_method             = aws_api_gateway_method.svc_proxy[each.key].http_method
  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  connection_type         = local.conn_type
  connection_id           = local.conn_id
  uri                     = "${local.svc_base[each.key]}/${each.value.path}/{proxy}"
  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
}

# ===== 배포 + 스테이지 =====

resource "aws_cloudwatch_log_group" "access_log" {
  count             = var.enable_access_logs ? 1 : 0
  name              = "/aws/apigateway/${local.name}-access-log"
  retention_in_days = 14
}

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  triggers = {
    redeployment = sha1(jsonencode(concat([
      aws_api_gateway_method.reservations_post.id,
      aws_api_gateway_integration.reservations_post.id,
      aws_api_gateway_method.reservations_get.id,
      aws_api_gateway_integration.reservations_get.id,
      aws_api_gateway_method.queue.id,
      aws_api_gateway_integration.queue.id,
      aws_api_gateway_method.seats_occupied.id,
      aws_api_gateway_integration.seats_occupied.id,
      local.conn_id,
      var.backend,
      jsonencode(local.svc_base),
      aws_api_gateway_authorizer.reservation.id,
      aws_api_gateway_gateway_response.unauthorized.id,
      aws_api_gateway_gateway_response.unauthorized.status_code,
      aws_api_gateway_gateway_response.access_denied.id,
      aws_api_gateway_gateway_response.access_denied.status_code,
      jsonencode(local.cors_response_headers),
      jsonencode(local.gateway_cors_headers),
      ],
      values(aws_api_gateway_method.reservation_item)[*].id,
      values(aws_api_gateway_integration.reservation_item)[*].id,
      values(aws_api_gateway_resource.svc_root)[*].id,
      values(aws_api_gateway_method.svc_root)[*].id,
      values(aws_api_gateway_integration.svc_root)[*].id,
      values(aws_api_gateway_resource.svc_proxy)[*].id,
      values(aws_api_gateway_method.svc_proxy)[*].id,
      values(aws_api_gateway_integration.svc_proxy)[*].id,
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
    aws_api_gateway_method.reservations_post,
    aws_api_gateway_integration.reservations_post,
    aws_api_gateway_method.reservations_get,
    aws_api_gateway_integration.reservations_get,
    aws_api_gateway_method.reservation_item,
    aws_api_gateway_integration.reservation_item,
    aws_api_gateway_method.cors,
    aws_api_gateway_integration.cors,
    aws_api_gateway_method_response.cors,
    aws_api_gateway_integration_response.cors,
    aws_api_gateway_method.queue,
    aws_api_gateway_integration.queue,
    aws_api_gateway_method.seats_occupied,
    aws_api_gateway_integration.seats_occupied,
    aws_api_gateway_method.captcha_challenge,
    aws_api_gateway_integration.captcha_challenge,
    aws_api_gateway_integration.svc_root,
    aws_api_gateway_integration.svc_proxy,
    aws_api_gateway_authorizer.reservation,
    aws_api_gateway_gateway_response.unauthorized,
    aws_api_gateway_gateway_response.access_denied
  ]
}

# API Gateway 계정/리전 단위 CloudWatch Logs 푸시 역할 — stage access 로깅 활성화의 전제(계정당 1회)
resource "aws_iam_role" "cloudwatch" {
  count = var.enable_access_logs ? 1 : 0
  name  = "${var.project_name}-${var.environment}-apigw-cloudwatch"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "apigateway.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  count      = var.enable_access_logs ? 1 : 0
  role       = aws_iam_role.cloudwatch[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_api_gateway_account" "this" {
  count               = var.enable_access_logs ? 1 : 0
  cloudwatch_role_arn = aws_iam_role.cloudwatch[0].arn

  depends_on = [aws_iam_role_policy_attachment.cloudwatch]
}

resource "aws_api_gateway_stage" "this" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id
  stage_name    = var.environment

  # 계정 CW Logs 역할 설정 후 access 로깅 활성(미설정 시 UpdateStage 400)
  depends_on = [aws_api_gateway_account.this]

  dynamic "access_log_settings" {
    for_each = var.enable_access_logs ? [1] : []
    content {
      destination_arn = aws_cloudwatch_log_group.access_log[0].arn

      format = jsonencode({
        requestId      = "$context.requestId"
        ip             = "$context.identity.sourceIp"
        requestTime    = "$context.requestTime"
        httpMethod     = "$context.httpMethod"
        resourcePath   = "$context.resourcePath"
        path           = "$context.path"
        status         = "$context.status"
        responseLength = "$context.responseLength"
        userAgent      = "$context.identity.userAgent"
      })
    }
  }
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
