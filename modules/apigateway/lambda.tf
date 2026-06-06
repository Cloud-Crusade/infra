data "archive_file" "authorizer" {
  type        = "zip"
  source_dir  = "${path.module}/src/authorizer"
  output_path = "${path.module}/build/authorizer.zip"
}

data "archive_file" "queue" {
  type        = "zip"
  source_dir  = "${path.module}/src/queue"
  output_path = "${path.module}/build/queue.zip"
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${local.name}-apigw-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "authorizer" {
  function_name    = "${local.name}-reservation-authorizer"
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  filename         = data.archive_file.authorizer.output_path
  source_code_hash = data.archive_file.authorizer.output_base64sha256
}

resource "aws_lambda_function" "queue" {
  function_name    = "${local.name}-queue"
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  filename         = data.archive_file.queue.output_path
  source_code_hash = data.archive_file.queue.output_base64sha256
}

resource "aws_lambda_permission" "authorizer" {
  statement_id  = "AllowApiGatewayInvokeAuthorizer"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.authorizer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/authorizers/${aws_apigatewayv2_authorizer.reservation.id}"
}

resource "aws_lambda_permission" "queue" {
  statement_id  = "AllowApiGatewayInvokeQueue"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.queue.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*/queue/{event_id}"
}
