# 배포 대상 목록 — S3 의 lambda-modules.txt (한 줄 = 모듈명, # 주석/빈 줄 제외)
data "aws_s3_object" "modules_list" {
  bucket = var.artifact_bucket
  key    = "${var.artifact_prefix}lambda-modules.txt"

  # Content-Type 이 text 계열이 아니면 body 가 빈 문자열로 와서 모듈 목록이 조용히 비고
  # → 기존 Lambda 가 전부 삭제되는 플랜이 나올 수 있어 fail-fast
  lifecycle {
    postcondition {
      condition     = startswith(coalesce(self.content_type, ""), "text/") && trimspace(self.body) != ""
      error_message = "lambda-modules.txt 를 읽지 못했습니다 (Content-Type 이 text 계열이 아니거나 본문이 비어 있음). text/plain 으로 업로드하세요."
    }
  }
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

  # function_url_modules 에 오타/미존재 모듈이 들어가면 조용히 무시되지 않도록 조기 실패
  lifecycle {
    precondition {
      condition     = length(setsubtract(var.function_url_modules, local.modules)) == 0
      error_message = "function_url_modules 에 lambda-modules.txt 에 없는 모듈이 있습니다: ${join(", ", setsubtract(var.function_url_modules, local.modules))}"
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
