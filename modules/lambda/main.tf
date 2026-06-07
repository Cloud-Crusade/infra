# 배포 대상 목록 — S3 의 lambda-modules.txt (한 줄 = 모듈명, # 주석/빈 줄 제외)
data "aws_s3_object" "modules_list" {
  bucket = var.artifact_bucket
  key    = "${var.artifact_prefix}lambda-modules.txt"
}

locals {
  modules = toset([
    for line in split("\n", trimspace(data.aws_s3_object.modules_list.body)) :
    trimspace(line) if trimspace(line) != "" && !startswith(trimspace(line), "#")
  ])
}

resource "aws_lambda_function" "this" {
  for_each = local.modules

  function_name = "${var.project_name}-${var.environment}-${each.key}"
  role          = var.lambda_role_arn
  runtime       = var.runtime
  handler       = var.handler
  timeout       = var.timeout

  # 코드: S3 zip (lambda/<module>.zip)
  s3_bucket = var.artifact_bucket
  s3_key    = "${var.artifact_prefix}${each.key}.zip"

  # lambda_env 에 해당 모듈이 있을 때만 environment 생성 (없으면 미주입)
  dynamic "environment" {
    for_each = length(lookup(var.lambda_env, each.key, {})) > 0 ? [1] : []
    content {
      variables = var.lambda_env[each.key]
    }
  }
}

# Function URL — 명시한 모듈만 생성(기본 없음)
resource "aws_lambda_function_url" "this" {
  for_each = setintersection(local.modules, var.function_url_modules)

  function_name      = aws_lambda_function.this[each.key].function_name
  authorization_type = "NONE"

  cors {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST"]
    allow_headers = ["content-type"]
  }
}
