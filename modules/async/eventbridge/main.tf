# CloudWatch Alarm 상태 변경(ALARM) → default 버스 → bot_block Lambda
# bot_block 서비스는 알람 발생 시각 기준 Logs Insights 로 의심 IP 를 조회해 Redis 블랙리스트에 등록
resource "aws_cloudwatch_event_rule" "bot_detection_rule" {
  name        = "${var.project_name}-${var.environment}-bot-detection-rule"
  description = "Bot detection event filtering rule"

  event_pattern = jsonencode({
    source      = ["aws.cloudwatch"]
    "detail-type" = ["CloudWatch Alarm State Change"]
    detail = {
      state     = { value = ["ALARM"] }
      alarmName = [{ prefix = "${var.project_name}-${var.environment}" }]
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