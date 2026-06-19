# Lambda 실행 IAM — 모든 함수 공통 역할 + 최소권한 정책
resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# CloudWatch 로그 쓰기
resource "aws_iam_policy" "logging" {
  name        = "${var.project_name}-lambda-logging-policy"
  description = "Lambda minimum policy for CloudWatch logging"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "arn:aws:logs:*:*:*"
    }]
  })
}

# Secrets Manager 읽기
resource "aws_iam_policy" "secrets" {
  name        = "${var.project_name}-lambda-secrets-policy"
  description = "Lambda minimum policy for Secrets Manager read"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      Resource = "*"
    }]
  })
}

# CloudWatch Logs Insights 조회(bot_block 람다 — 의심 IP 탐지)
resource "aws_iam_policy" "logs_query" {
  name        = "${var.project_name}-lambda-logs-query-policy"
  description = "Lambda policy for CloudWatch Logs Insights query"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:StartQuery", "logs:GetQueryResults"]
      Resource = "arn:aws:logs:*:*:*"
    }]
  })
}

# SQS 소비(persistence 람다 event source mapping)
resource "aws_iam_policy" "sqs" {
  name        = "${var.project_name}-lambda-sqs-policy"
  description = "Lambda SQS consume (event source mapping)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "logging" {
  policy_arn = aws_iam_policy.logging.arn
  role       = aws_iam_role.lambda.name
}

resource "aws_iam_role_policy_attachment" "logs_query" {
  policy_arn = aws_iam_policy.logs_query.arn
  role       = aws_iam_role.lambda.name
}

resource "aws_iam_role_policy_attachment" "secrets" {
  policy_arn = aws_iam_policy.secrets.arn
  role       = aws_iam_role.lambda.name
}

resource "aws_iam_role_policy_attachment" "sqs" {
  policy_arn = aws_iam_policy.sqs.arn
  role       = aws_iam_role.lambda.name
}

# VPC 연결 람다 ENI 권한(ElastiCache/RDS 등 VPC 내부 접근)
resource "aws_iam_role_policy_attachment" "vpc_access" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  role       = aws_iam_role.lambda.name
}
