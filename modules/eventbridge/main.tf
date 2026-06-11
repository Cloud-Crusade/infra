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