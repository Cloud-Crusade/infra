resource "aws_cloudwatch_event_bus" "bot_detection" {
  name = "${var.project_name}-${var.environment}-bot-detection"
}

resource "aws_cloudwatch_event_rule" "bot_detection_rule" {
  name           = "${var.project_name}-${var.environment}-bot-detection-rule"
  description    = "Bot detection event filtering rule"
  event_bus_name = aws_cloudwatch_event_bus.bot_detection.name

  event_pattern = jsonencode({
    source = ["cloudfront.bot-detection"]
  })
}

resource "aws_cloudwatch_event_target" "bot_detection_lambda" {
  rule           = aws_cloudwatch_event_rule.bot_detection_rule.name
  event_bus_name = aws_cloudwatch_event_bus.bot_detection.name
  target_id      = "bot-detection-lambda"
  arn            = var.target_lambda_arn
}

resource "aws_lambda_permission" "allow_eventbridge_bot_detection" {
  statement_id  = "AllowExecutionFromEventBridgeBotDetection"
  action        = "lambda:InvokeFunction"
  function_name = var.target_lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.bot_detection_rule.arn
}