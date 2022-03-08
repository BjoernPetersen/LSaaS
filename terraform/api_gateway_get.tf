resource "aws_lambda_function" "get_result" {
  function_name = "${var.function_name_prefix}-getResult"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.9"
  handler       = "main.get_result"
  timeout       = 30

  filename         = "../code.zip"
  source_code_hash = filebase64sha256("../code.zip")

  layers = [aws_lambda_layer_version.lsaas.arn]

  environment {
    variables = {
      S3_BUCKET_NAME = aws_s3_bucket.bucket.id
    }
  }
}

resource "aws_lambda_permission" "invoke_get" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_result.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*/*"
}

resource "aws_api_gateway_resource" "token" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "{token}"
}

resource "aws_api_gateway_method" "get" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.token.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.token.id
  http_method             = aws_api_gateway_method.get.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = aws_lambda_function.get_result.invoke_arn

  passthrough_behavior = "NEVER"
  request_templates = {
    "application/json" = <<EOF
{
  "token" : "$input.params('token')"
}
EOF
  }
}

resource "aws_api_gateway_integration_response" "result_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.token.id
  http_method = aws_api_gateway_method.get.http_method
  status_code = aws_api_gateway_method_response.get_ok.status_code

  depends_on = [
    aws_api_gateway_integration.get
  ]
}

resource "aws_api_gateway_method_response" "get_ok" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.token.id
  http_method = aws_api_gateway_method.get.http_method
  status_code = "200"

  response_models = {
    "application/json" = aws_api_gateway_model.result_response.name
  }
}
