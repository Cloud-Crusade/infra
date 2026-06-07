locals {
  name = "${var.project_name}-${var.environment}"
}

resource "aws_api_gateway_rest_api" "this" {
  name = "${local.name}-rest-api"
}

# 예약 토큰(Reservation) RS256 서명 검증 Lambda authorizer
# authorizer 람다가 S3 의 reservation 공개키로 서명 검증(공개키 위치는 authorizer 람다 env)
# - Reservation 헤더 없음 → 401, 서명 무효 → 403, 유효 → 통과
resource "aws_api_gateway_authorizer" "reservation" {
  name            = "${local.name}-reservation-authorizer"
  rest_api_id     = aws_api_gateway_rest_api.this.id
  type            = "REQUEST"
  authorizer_uri  = var.authorizer_lambda_invoke_arn
  identity_source = "method.request.header.Reservation"
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
    redeployment = sha1(jsonencode([
      aws_api_gateway_method.reservations,
      aws_api_gateway_integration.reservations,
      aws_api_gateway_method.reservation_item,
      aws_api_gateway_integration.reservation_item,
      aws_api_gateway_method.queue,
      aws_api_gateway_integration.queue,
      aws_api_gateway_method.proxy,
      aws_api_gateway_integration.proxy,
      aws_api_gateway_authorizer.reservation,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
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

# 게이트웨이 → authorizer Lambda invoke 권한
resource "aws_lambda_permission" "authorizer" {
  statement_id  = "AllowApiGatewayInvokeAuthorizer"
  action        = "lambda:InvokeFunction"
  function_name = var.authorizer_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/authorizers/${aws_api_gateway_authorizer.reservation.id}"
}
