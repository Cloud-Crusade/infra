# API Gateway 액세스 로그에서 429 응답을 카운트하는 메트릭 필터
# 로그 포맷은 apigateway/main.tf access_log_settings format 의 JSON 구조와 일치 ($.status)
resource "aws_cloudwatch_log_metric_filter" "apigw_429" {
  name           = "${var.project_name}-${var.environment}-apigw-429-filter"
  pattern        = "{ $.status = 429 }"
  log_group_name = "/aws/apigateway/${var.project_name}-${var.environment}-access-log"

  metric_transformation {
    name      = "ApiGateway429Count"
    namespace = "${var.project_name}/${var.environment}"
    value     = "1"
  }
}

# 429 스파이크 전용 알람 — bot_block 트리거 전용이므로 알람명을 EventBridge rule 과 1:1 매핑
resource "aws_cloudwatch_metric_alarm" "apigw_429" {
  alarm_name          = "${var.project_name}-${var.environment}-apigw-429-alarm"
  alarm_description   = "API Gateway 429 Too Many Requests spike — triggers bot_block Lambda"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = aws_cloudwatch_log_metric_filter.apigw_429.metric_transformation[0].name
  namespace           = aws_cloudwatch_log_metric_filter.apigw_429.metric_transformation[0].namespace
  period              = 60
  statistic           = "Sum"
  threshold           = var.apigw_429_threshold
  treat_missing_data  = "notBreaching"
}

# CloudWatch Alarm 상태 변경(ALARM) → default 버스 → bot_block Lambda
# 429 전용 알람만 필터링 — 기존 prefix 매칭은 RDS/EKS 등 무관 알람도 트리거하는 문제가 있었음
resource "aws_cloudwatch_event_rule" "bot_detection_rule" {
  name        = "${var.project_name}-${var.environment}-bot-detection-rule"
  description = "API Gateway 429 spike alarm → bot_block Lambda"

  event_pattern = jsonencode({
    source        = ["aws.cloudwatch"]
    "detail-type" = ["CloudWatch Alarm State Change"]
    detail = {
      alarmName = [aws_cloudwatch_metric_alarm.apigw_429.alarm_name]
      state     = { value = ["ALARM"] }
    }
  })
}

resource "aws_cloudwatch_event_target" "bot_detection_lambda" {
  rule      = aws_cloudwatch_event_rule.bot_detection_rule.name
  target_id = "bot-detection-lambda"
  arn       = var.target_lambda_arn
}

resource "aws_lambda_permission" "allow_eventbridge_bot_detection" {
  statement_id  = "AllowExecutionFromEventBridgeBotDetection"
  action        = "lambda:InvokeFunction"
  function_name = var.target_lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.bot_detection_rule.arn
}