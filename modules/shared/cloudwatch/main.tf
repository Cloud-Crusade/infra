# 대시보드 metric 위젯 region 지정용
data "aws_region" "current" {}

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
# 로그 그룹은 lambda 모듈이 소유(logging_config 로 런타임 자동 생성 충돌 회피) → 여기선 알람만.

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
      # SQS
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 8
        height = 6

        properties = {
          region  = data.aws_region.current.region
          title   = "SQS Queue Depth"
          metrics = [for q in var.sqs_queue_names : ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", q]]
          period  = 300
          stat    = "Average"
          view    = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 0
        width  = 8
        height = 6

        properties = {
          region  = data.aws_region.current.region
          title   = "SQS Oldest Message"
          metrics = [for q in var.sqs_queue_names : ["AWS/SQS", "ApproximateAgeOfOldestMessage", "QueueName", q]]
          period  = 300
          stat    = "Maximum"
          view    = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 0
        width  = 8
        height = 6

        properties = {
          region  = data.aws_region.current.region
          title   = "SQS Messages Received"
          metrics = [for q in var.sqs_queue_names : ["AWS/SQS", "NumberOfMessagesReceived", "QueueName", q]]
          period  = 300
          stat    = "Sum"
          view    = "timeSeries"
        }
      },

      # ElastiCache CPU
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          region = data.aws_region.current.region
          title  = "Main Cache CPU"

          metrics = [
            ["AWS/ElastiCache", "EngineCPUUtilization", "CacheClusterId", var.elasticache_cluster_ids[0], "CacheNodeId", "0001"]
          ]

          period = 300
          stat   = "Average"
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6

        properties = {
          region = data.aws_region.current.region
          title  = "Waiting Room Cache CPU"

          metrics = [
            ["AWS/ElastiCache", "EngineCPUUtilization", "CacheClusterId", var.elasticache_cluster_ids[1], "CacheNodeId", "0001"]
          ]

          period = 300
          stat   = "Average"
          view   = "timeSeries"
        }
      },

      # ElastiCache Connections
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6

        properties = {
          region = data.aws_region.current.region
          title  = "Main Cache Connections"

          metrics = [
            ["AWS/ElastiCache", "CurrConnections", "CacheClusterId", var.elasticache_cluster_ids[0], "CacheNodeId", "0001"]
          ]

          period = 300
          stat   = "Average"
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6

        properties = {
          region = data.aws_region.current.region
          title  = "Waiting Room Cache Connections"

          metrics = [
            ["AWS/ElastiCache", "CurrConnections", "CacheClusterId", var.elasticache_cluster_ids[1], "CacheNodeId", "0001"]
          ]

          period = 300
          stat   = "Average"
          view   = "timeSeries"
        }
      },

      # ElastiCache 통합 지표
      {
        type   = "metric"
        x      = 0
        y      = 18
        width  = 12
        height = 6

        properties = {
          region  = data.aws_region.current.region
          title   = "ElastiCache Memory Usage"
          metrics = [for id in var.elasticache_cluster_ids : ["AWS/ElastiCache", "DatabaseMemoryUsagePercentage", "CacheClusterId", id, "CacheNodeId", "0001"]]
          period  = 300
          stat    = "Average"
          view    = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 18
        width  = 12
        height = 6

        properties = {
          region  = data.aws_region.current.region
          title   = "ElastiCache Evictions"
          metrics = [for id in var.elasticache_cluster_ids : ["AWS/ElastiCache", "Evictions", "CacheClusterId", id, "CacheNodeId", "0001"]]
          period  = 300
          stat    = "Sum"
          view    = "timeSeries"
        }
      },

      # RDS CPU
      {
        type   = "metric"
        x      = 0
        y      = 24
        width  = 8
        height = 6

        properties = {
          region = data.aws_region.current.region
          title  = "Primary DB CPU"

          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.rds_instance_ids[0]]
          ]

          period = 300
          stat   = "Average"
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 24
        width  = 8
        height = 6

        properties = {
          region = data.aws_region.current.region
          title  = "Primary Replica DB CPU"

          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.rds_instance_ids[1]]
          ]

          period = 300
          stat   = "Average"
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 24
        width  = 8
        height = 6

        properties = {
          region = data.aws_region.current.region
          title  = "Reservation DB CPU"

          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.rds_instance_ids[2]]
          ]

          period = 300
          stat   = "Average"
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 30
        width  = 12
        height = 6

        properties = {
          region = data.aws_region.current.region
          title  = "Reservation Replica DB CPU"

          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.rds_instance_ids[3]]
          ]

          period = 300
          stat   = "Average"
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 30
        width  = 12
        height = 6

        properties = {
          region = data.aws_region.current.region
          title  = "Reservation Replica 2 DB CPU"

          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.rds_instance_ids[4]]
          ]

          period = 300
          stat   = "Average"
          view   = "timeSeries"
        }
      },

      # RDS Connections
      {
        type   = "metric"
        x      = 0
        y      = 36
        width  = 8
        height = 6

        properties = {
          region = data.aws_region.current.region
          title  = "Primary DB Connections"

          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", var.rds_instance_ids[0]]
          ]

          period = 300
          stat   = "Average"
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 36
        width  = 8
        height = 6

        properties = {
          region = data.aws_region.current.region
          title  = "Primary Replica DB Connections"

          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", var.rds_instance_ids[1]]
          ]

          period = 300
          stat   = "Average"
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 36
        width  = 8
        height = 6

        properties = {
          region = data.aws_region.current.region
          title  = "Reservation DB Connections"

          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", var.rds_instance_ids[2]]
          ]

          period = 300
          stat   = "Average"
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 42
        width  = 12
        height = 6

        properties = {
          region = data.aws_region.current.region
          title  = "Reservation Replica DB Connections"

          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", var.rds_instance_ids[3]]
          ]

          period = 300
          stat   = "Average"
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 42
        width  = 12
        height = 6

        properties = {
          region = data.aws_region.current.region
          title  = "Reservation Replica 2 DB Connections"

          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", var.rds_instance_ids[4]]
          ]

          period = 300
          stat   = "Average"
          view   = "timeSeries"
        }
      },

      # RDS Latency
      {
        type   = "metric"
        x      = 0
        y      = 48
        width  = 12
        height = 6

        properties = {
          region  = data.aws_region.current.region
          title   = "RDS Read Latency"
          metrics = [for id in var.rds_instance_ids : ["AWS/RDS", "ReadLatency", "DBInstanceIdentifier", id]]
          period  = 300
          stat    = "Average"
          view    = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 48
        width  = 12
        height = 6

        properties = {
          region  = data.aws_region.current.region
          title   = "RDS Write Latency"
          metrics = [for id in var.rds_instance_ids : ["AWS/RDS", "WriteLatency", "DBInstanceIdentifier", id]]
          period  = 300
          stat    = "Average"
          view    = "timeSeries"
        }
      },

      # Lambda
      {
        type   = "metric"
        x      = 0
        y      = 54
        width  = 6
        height = 6

        properties = {
          region  = data.aws_region.current.region
          title   = "Lambda Invocations"
          metrics = [for fn in var.lambda_function_names : ["AWS/Lambda", "Invocations", "FunctionName", fn]]
          period  = 60
          stat    = "Sum"
          view    = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 6
        y      = 54
        width  = 6
        height = 6

        properties = {
          region  = data.aws_region.current.region
          title   = "Lambda Errors"
          metrics = [for fn in var.lambda_function_names : ["AWS/Lambda", "Errors", "FunctionName", fn]]
          period  = 60
          stat    = "Sum"
          view    = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 54
        width  = 6
        height = 6

        properties = {
          region  = data.aws_region.current.region
          title   = "Lambda Duration"
          metrics = [for fn in var.lambda_function_names : ["AWS/Lambda", "Duration", "FunctionName", fn]]
          period  = 60
          stat    = "Average"
          view    = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 18
        y      = 54
        width  = 6
        height = 6

        properties = {
          region  = data.aws_region.current.region
          title   = "Lambda Throttles"
          metrics = [for fn in var.lambda_function_names : ["AWS/Lambda", "Throttles", "FunctionName", fn]]
          period  = 60
          stat    = "Sum"
          view    = "timeSeries"
        }
      },

      # CloudFront
      {
        type   = "metric"
        x      = 0
        y      = 60
        width  = 24
        height = 6

        properties = {
          # CloudFront 지표는 글로벌 → CloudWatch us-east-1 에만 보고
          region = "us-east-1"
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

resource "aws_cloudwatch_metric_alarm" "arc_zonal_shift" {
  alarm_name          = "arc-zonal-shift-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 0
  treat_missing_data  = "notBreaching"

  # 서비스별 TG UnHealthyHostCount (개별 메트릭, 합산 입력용)
  dynamic "metric_query" {
    for_each = var.target_group_arn_suffixes
    iterator = tg

    content {
      id          = "m_${tg.key}"
      return_data = false

      metric {
        metric_name = "UnHealthyHostCount"
        namespace   = "AWS/NetworkELB"
        period      = 60
        stat        = "Maximum"

        dimensions = {
          LoadBalancer = var.lb_arn_suffix
          TargetGroup  = tg.value
        }
      }
    }
  }

  # 전체 TG 합산 — 어느 한 TG라도 unhealthy host 가 있으면 알람
  metric_query {
    id          = "total_unhealthy"
    expression  = join(" + ", [for k in keys(var.target_group_arn_suffixes) : "m_${k}"])
    label       = "TotalUnhealthyHosts"
    return_data = true
  }

  alarm_description = "ARC Zonal Shift outcome alarm — NLB 전체 TG UnHealthyHostCount 합산"
  actions_enabled   = var.enable_az_failover
}