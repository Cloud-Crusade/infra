
resource "aws_lambda_function" "queue_lambda" {
  for_each = var.lambdas

  filename         = data.archive_file.lambda_zip[each.key].output_path
  function_name    = each.value.function_name
  role             = var.lambda_role_arn
  handler          = each.value.handler
  source_code_hash = data.archive_file.lambda_zip[each.key].output_base64sha256
  runtime          = "python3.11"
  timeout          = each.value.timeout

  layers = each.value.lambda_layers

  environment {
    variables = each.value.lambda_env
  }
}

# Function URL 생성
resource "aws_lambda_function_url" "lambda_url" {
  for_each = var.lambdas

  function_name      = aws_lambda_function.queue_lambda[each.key].function_name
  authorization_type = "NONE"

  cors {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST"]
    allow_headers = ["content-type"]
  }

}