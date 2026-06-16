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

# 로그 그룹을 terraform 이 선점 소유 — 함수가 logging_config 로 이 그룹을 명시해 런타임 자동 생성(ResourceAlreadyExists 충돌) 차단
resource "aws_cloudwatch_log_group" "this" {
  for_each = local.modules

  name              = "/aws/lambda/${var.project_name}-${var.environment}-${each.key}"
  retention_in_days = var.log_retention_in_days
}

resource "aws_lambda_function" "this" {
  for_each = local.modules

  function_name = "${var.project_name}-${var.environment}-${each.key}"
  role          = var.lambda_role_arn
  runtime       = var.runtime
  handler       = var.handler
  timeout       = var.timeout

  # 모듈별 Lambda Layer (예: captcha 의 Secrets 확장 레이어 — 런타임 시크릿 캐시 조회)
  layers = lookup(var.layers, each.key, null)

  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.this[each.key].name
  }

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

  # vpc_modules 에 포함된 모듈만 VPC 연결 (ElastiCache/RDS 등 VPC 내부 접근)
  dynamic "vpc_config" {
    for_each = contains(var.vpc_modules, each.key) ? [1] : []
    content {
      subnet_ids         = var.vpc_subnet_ids
      security_group_ids = var.vpc_security_group_ids
    }
  }

  # function_url_modules / vpc_modules 에 오타·미존재 모듈이 들어가면 조기 실패
  lifecycle {
    precondition {
      condition     = length(setsubtract(var.function_url_modules, local.modules)) == 0
      error_message = "function_url_modules 에 lambda-modules.txt 에 없는 모듈이 있습니다: ${join(", ", setsubtract(var.function_url_modules, local.modules))}"
    }
    precondition {
      condition     = length(setsubtract(var.vpc_modules, local.modules)) == 0
      error_message = "vpc_modules 에 lambda-modules.txt 에 없는 모듈이 있습니다: ${join(", ", setsubtract(var.vpc_modules, local.modules))}"
    }
    # vpc_modules 사용 시 서브넷·SG 가 비면 vpc_config 가 빈 값으로 생성돼 apply 가 실패 → 조기 검출
    precondition {
      condition     = length(var.vpc_modules) == 0 || (length(var.vpc_subnet_ids) > 0 && length(var.vpc_security_group_ids) > 0)
      error_message = "vpc_modules 사용 시 vpc_subnet_ids 와 vpc_security_group_ids 가 비어있지 않아야 합니다."
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
