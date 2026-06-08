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
  period              = 60
  evaluation_periods  = 3
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
  for_each = var.cloudfront_distribution_id != "" ? toset([var.cloudfront_distribution_id]) : toset([])

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
    DistributionId = each.key
    Region         = "Global"
  }

  alarm_actions = [aws_sns_topic.alarm.arn]
  ok_actions    = [aws_sns_topic.alarm.arn]
}

resource "aws_cloudwatch_metric_alarm" "cloudfront_4xx" {
  for_each = var.cloudfront_distribution_id != "" ? toset([var.cloudfront_distribution_id]) : toset([])

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
    DistributionId = each.key
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

# ===== API Gateway 알람 (모듈 연결 후 활성화) =====

resource "aws_cloudwatch_metric_alarm" "apigw_5xx" {
  for_each = var.api_gateway_name != "" ? toset([var.api_gateway_name]) : toset([])

  alarm_name          = "${var.project_name}-${var.environment}-apigw-5xx"
  alarm_description   = "API Gateway 5xx 에러율 5% 초과"
  namespace           = "AWS/ApiGateway"
  metric_name         = "5XXError"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 5
  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    ApiName = each.key
    Stage   = var.environment
  }

  alarm_actions = [aws_sns_topic.alarm.arn]
  ok_actions    = [aws_sns_topic.alarm.arn]
}

resource "aws_cloudwatch_metric_alarm" "apigw_4xx" {
  for_each = var.api_gateway_name != "" ? toset([var.api_gateway_name]) : toset([])

  alarm_name          = "${var.project_name}-${var.environment}-apigw-4xx"
  alarm_description   = "API Gateway 4xx 에러율 10% 초과"
  namespace           = "AWS/ApiGateway"
  metric_name         = "4XXError"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 10
  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    ApiName = each.key
    Stage   = var.environment
  }

  alarm_actions = [aws_sns_topic.alarm.arn]
  ok_actions    = [aws_sns_topic.alarm.arn]
}

resource "aws_cloudwatch_metric_alarm" "apigw_latency" {
  for_each = var.api_gateway_name != "" ? toset([var.api_gateway_name]) : toset([])

  alarm_name          = "${var.project_name}-${var.environment}-apigw-latency"
  alarm_description   = "API Gateway 응답 시간 5초 초과"
  namespace           = "AWS/ApiGateway"
  metric_name         = "Latency"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 5000
  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    ApiName = each.key
    Stage   = var.environment
  }

  alarm_actions = [aws_sns_topic.alarm.arn]
  ok_actions    = [aws_sns_topic.alarm.arn]
}

# ===== CloudWatch 대시보드 =====

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      # Lambda 에러
      {
        type = "metric"
        properties = {
          title  = "Lambda Errors"
          metrics = [for fn in var.lambda_function_names : ["AWS/Lambda", "Errors", "FunctionName", fn]]
          period = 60
          stat   = "Sum"
          view   = "timeSeries"
        }
      },
      # Lambda 실행 시간
      {
        type = "metric"
        properties = {
          title  = "Lambda Duration"
          metrics = [for fn in var.lambda_function_names : ["AWS/Lambda", "Duration", "FunctionName", fn]]
          period = 60
          stat   = "Average"
          view   = "timeSeries"
        }
      },
      # RDS CPU
      {
        type = "metric"
        properties = {
          title  = "RDS CPU Utilization"
          metrics = [for id in var.rds_instance_ids : ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", id]]
          period = 300
          stat   = "Average"
          view   = "timeSeries"
        }
      },
      # CloudFront 에러율
      {
        type = "metric"
        properties = {
          title  = "CloudFront Error Rate"
          metrics = var.cloudfront_distribution_id != "" ? [
            ["AWS/CloudFront", "5xxErrorRate", "DistributionId", var.cloudfront_distribution_id, "Region", "Global"],
            ["AWS/CloudFront", "4xxErrorRate", "DistributionId", var.cloudfront_distribution_id, "Region", "Global"]
          ] : []
          period = 300
          stat   = "Average"
          view   = "timeSeries"
        }
      }
    ]
  })
}
