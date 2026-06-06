locals {
  name = "${var.project_name}-${var.environment}"
}

resource "aws_apigatewayv2_api" "this" {
  name          = "${local.name}-http-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true
}

# 예약 경로 authorizer — Reservation 헤더 존재만 검사(외부 Lambda).
# identity_sources 미지정 → 헤더가 없어도 authorizer 가 호출되어 거부(403)를 낸다(401 아님).
resource "aws_apigatewayv2_authorizer" "reservation" {
  api_id                            = aws_apigatewayv2_api.this.id
  name                              = "${local.name}-reservation-authorizer"
  authorizer_type                   = "REQUEST"
  authorizer_uri                    = var.authorizer_lambda_invoke_arn
  authorizer_payload_format_version = "2.0"
  enable_simple_responses           = true
}

# ===== 통합 =====
resource "aws_apigatewayv2_integration" "queue" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.queue_lambda_invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "reservations" {
  api_id           = aws_apigatewayv2_api.this.id
  integration_type = "HTTP_PROXY"
  integration_uri  = "${var.reservation_backend_url}/reservations"
}

resource "aws_apigatewayv2_integration" "reservation_item" {
  api_id           = aws_apigatewayv2_api.this.id
  integration_type = "HTTP_PROXY"
  integration_uri  = "${var.reservation_backend_url}/reservations/{reservation_id}"
}

# 그 외 모든 경로 → app 백엔드(EKS). Authorization 인증은 EKS 가 판별.
resource "aws_apigatewayv2_integration" "app" {
  api_id           = aws_apigatewayv2_api.this.id
  integration_type = "HTTP_PROXY"
  integration_uri  = "${var.app_backend_url}/{proxy}"
}

# ===== 라우트 =====
resource "aws_apigatewayv2_route" "queue" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "ANY /queue/{event_id}"
  target    = "integrations/${aws_apigatewayv2_integration.queue.id}"
}

resource "aws_apigatewayv2_route" "reservations" {
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "ANY /reservations"
  target             = "integrations/${aws_apigatewayv2_integration.reservations.id}"
  authorization_type = "CUSTOM"
  authorizer_id      = aws_apigatewayv2_authorizer.reservation.id
}

resource "aws_apigatewayv2_route" "reservation_item" {
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "ANY /reservations/{reservation_id}"
  target             = "integrations/${aws_apigatewayv2_integration.reservation_item.id}"
  authorization_type = "CUSTOM"
  authorizer_id      = aws_apigatewayv2_authorizer.reservation.id
}

resource "aws_apigatewayv2_route" "proxy" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.app.id}"
}

# ===== 게이트웨이 → Lambda invoke 권한 (Lambda 자체는 외부 생성) =====
resource "aws_lambda_permission" "authorizer" {
  statement_id  = "AllowApiGatewayInvokeAuthorizer"
  action        = "lambda:InvokeFunction"
  function_name = var.authorizer_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/authorizers/${aws_apigatewayv2_authorizer.reservation.id}"
}

resource "aws_lambda_permission" "queue" {
  statement_id  = "AllowApiGatewayInvokeQueue"
  action        = "lambda:InvokeFunction"
  function_name = var.queue_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*/queue/{event_id}"
}
