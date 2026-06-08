# ===== SNS 토픽 =====

resource "aws_sns_topic" "alarm" {
  name = "${var.project_name}-${var.environment}-cloudwatch-alarm"
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alarm_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alarm.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# ===== RDS 알람 =====

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  for_each = toset(var.rds_instance_ids)

  alarm_name          = "${var.project_name}-${var.environment}-rds-cpu-${each.key}"
  alarm_description   = "RDS CPU 사용률 80% 초과"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    DBInstanceIdentifier = each.key
  }

  alarm_actions = [aws_sns_topic.alarm.arn]
  ok_actions    = [aws_sns_topic.alarm.arn]
}

resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  for_each = toset(var.rds_instance_ids)

  alarm_name          = "${var.project_name}-${var.environment}-rds-connections-${each.key}"
  alarm_description   = "RDS 연결 수 100 초과"
  namespace           = "AWS/RDS"
  metric_name         = "DatabaseConnections"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 100
  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    DBInstanceIdentifier = each.key
  }

  alarm_actions = [aws_sns_topic.alarm.arn]
  ok_actions    = [aws_sns_topic.alarm.arn]
}

resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  for_each = toset(var.rds_instance_ids)

  alarm_name          = "${var.project_name}-${var.environment}-rds-storage-${each.key}"
  alarm_description   = "RDS 남은 스토리지 2GB 미만"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 2147483648
  comparison_operator = "LessThanThreshold"

  dimensions = {
    DBInstanceIdentifier = each.key
  }

  alarm_actions = [aws_sns_topic.alarm.arn]
  ok_actions    = [aws_sns_topic.alarm.arn]
}

# ===== Lambda 알람 =====

resource "aws_cloudwatch_log_group" "lambda" {
  for_each = toset(var.lambda_function_names)

  name              = "/aws/lambda/${each.key}"
  retention_in_days = 14
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each = toset(var.lambda_function_names)

  alarm_name          = "${var.project_name}-${var.environment}-lambda-errors-${each.key}"
  alarm_description   = "Lambda 에러 발생"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"

  dimensions = {
    FunctionName = each.key
  }

  alarm_actions = [aws_sns_topic.alarm.arn]
  ok_actions    = [aws_sns_topic.alarm.arn]
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  for_each = toset(var.lambda_function_names)

  alarm_name          = "${var.project_name}-${var.environment}-lambda-duration-${each.key}"
  alarm_description   = "Lambda 실행 시간 10초 초과"
  namespace           = "AWS/Lambda"
  metric_name         = "Duration"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 10000
  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    FunctionName = each.key
  }

  alarm_actions = [aws_sns_topic.alarm.arn]
  ok_actions    = [aws_sns_topic.alarm.arn]
}

# ===== CloudFront 알람 =====

resource "aws_cloudwatch_metric_alarm" "cloudfront_5xx" {
  count = var.cloudfront_distribution_id != "" ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-cloudfront-5xx"
  alarm_description   = "CloudFront 5xx 에러율 5% 초과"
  namespace           = "AWS/CloudFront"
  metric_name         = "5xxErrorRate"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 5
  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    DistributionId = var.cloudfront_distribution_id
    Region         = "Global"
  }

  alarm_actions = [aws_sns_topic.alarm.arn]
  ok_actions    = [aws_sns_topic.alarm.arn]
}

resource "aws_cloudwatch_metric_alarm" "cloudfront_4xx" {
  count = var.cloudfront_distribution_id != "" ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-cloudfront-4xx"
  alarm_description   = "CloudFront 4xx 에러율 10% 초과"
  namespace           = "AWS/CloudFront"
  metric_name         = "4xxErrorRate"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 10
  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    DistributionId = var.cloudfront_distribution_id
    Region         = "Global"
  }

  alarm_actions = [aws_sns_topic.alarm.arn]
  ok_actions    = [aws_sns_topic.alarm.arn]
}

# ===== ElastiCache 알람 (틀만 — 모듈 연결 후 활성화) =====

resource "aws_cloudwatch_metric_alarm" "elasticache_cpu" {
  for_each = toset(var.elasticache_cluster_ids)

  alarm_name          = "${var.project_name}-${var.environment}-elasticache-cpu-${each.key}"
  alarm_description   = "ElastiCache CPU 사용률 80% 초과"
  namespace           = "AWS/ElastiCache"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    CacheClusterId = each.key
  }

  alarm_actions = [aws_sns_topic.alarm.arn]
  ok_actions    = [aws_sns_topic.alarm.arn]
}

resource "aws_cloudwatch_metric_alarm" "elasticache_memory" {
  for_each = toset(var.elasticache_cluster_ids)

  alarm_name          = "${var.project_name}-${var.environment}-elasticache-memory-${each.key}"
  alarm_description   = "ElastiCache 메모리 사용률 80% 초과"
  namespace           = "AWS/ElastiCache"
  metric_name         = "DatabaseMemoryUsagePercentage"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    CacheClusterId = each.key
  }

  alarm_actions = [aws_sns_topic.alarm.arn]
  ok_actions    = [aws_sns_topic.alarm.arn]
}

# ===== SQS 알람 (틀만 — 모듈 연결 후 활성화) =====

resource "aws_cloudwatch_metric_alarm" "sqs_depth" {
  for_each = toset(var.sqs_queue_names)

  alarm_name          = "${var.project_name}-${var.environment}-sqs-depth-${each.key}"
  alarm_description   = "SQS 큐 메시지 수 1000 초과"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 1000
  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    QueueName = each.key
  }

  alarm_actions = [aws_sns_topic.alarm.arn]
  ok_actions    = [aws_sns_topic.alarm.arn]
}

resource "aws_cloudwatch_metric_alarm" "sqs_age" {
  for_each = toset(var.sqs_queue_names)

  alarm_name          = "${var.project_name}-${var.environment}-sqs-age-${each.key}"
  alarm_description   = "SQS 메시지 최대 대기 시간 300초 초과"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateAgeOfOldestMessage"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 2
  threshold           = 300
  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    QueueName = each.key
  }

  alarm_actions = [aws_sns_topic.alarm.arn]
  ok_actions    = [aws_sns_topic.alarm.arn]
}

# ===== EKS 알람 (틀만 — 모듈 연결 후 활성화) =====

resource "aws_cloudwatch_metric_alarm" "eks_node_cpu" {
  count = var.eks_cluster_name != "" ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-eks-node-cpu"
  alarm_description   = "EKS 노드 CPU 사용률 80% 초과"
  namespace           = "ContainerInsights"
  metric_name         = "node_cpu_utilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    ClusterName = var.eks_cluster_name
  }

  alarm_actions = [aws_sns_topic.alarm.arn]
  ok_actions    = [aws_sns_topic.alarm.arn]
}

resource "aws_cloudwatch_metric_alarm" "eks_node_memory" {
  count = var.eks_cluster_name != "" ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-eks-node-memory"
  alarm_description   = "EKS 노드 메모리 사용률 80% 초과"
  namespace           = "ContainerInsights"
  metric_name         = "node_memory_utilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    ClusterName = var.eks_cluster_name
  }

  alarm_actions = [aws_sns_topic.alarm.arn]
  ok_actions    = [aws_sns_topic.alarm.arn]
}
