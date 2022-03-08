resource "aws_lambda_function" "post" {
  function_name = "${var.function_name_prefix}-post"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.9"
  handler       = "main.post_request"
  timeout       = 30

  filename         = "../code.zip"
  source_code_hash = filebase64sha256("../code.zip")

  layers = [aws_lambda_layer_version.lsaas.arn]

  environment {
    variables = {
      CLOUDFLARE_TOKEN     = var.cloudflare_token_lambda
      CLOUDFLARE_ZONE_ID   = var.cloudflare_zone_id
      CLOUDFLARE_ZONE_NAME = var.cloudflare_zone_name
      CLOUDFLARE_INFIX     = var.cloudflare_infix
      LAMBDA_NAME_RETRIEVE = aws_lambda_function.retrieve_cert.function_name
    }
  }
}

resource "aws_lambda_permission" "invoke_post" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.post.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*/*"
}

resource "aws_api_gateway_method" "post" {
  rest_api_id          = aws_api_gateway_rest_api.api.id
  resource_id          = aws_api_gateway_rest_api.api.root_resource_id
  http_method          = "POST"
  authorization        = "NONE"
  request_validator_id = aws_api_gateway_request_validator.validate_body.id

  request_models = {
    "application/json" = aws_api_gateway_model.initial_request.name
  }
}

resource "aws_api_gateway_method_response" "post_ok" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_rest_api.api.root_resource_id
  http_method = aws_api_gateway_method.post.http_method
  status_code = "200"

  response_models = {
    "application/json" = aws_api_gateway_model.domain_response.name
  }
}

resource "aws_api_gateway_method_response" "post_error" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_rest_api.api.root_resource_id
  http_method = aws_api_gateway_method.post.http_method
  status_code = "400"

  response_models = {
    "application/json" = "Error"
  }
}

resource "aws_api_gateway_integration" "post" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_rest_api.api.root_resource_id
  http_method             = aws_api_gateway_method.post.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = aws_lambda_function.post.invoke_arn
}

resource "aws_api_gateway_integration_response" "post_ok_response" {
  rest_api_id       = aws_api_gateway_rest_api.api.id
  resource_id       = aws_api_gateway_rest_api.api.root_resource_id
  http_method       = aws_api_gateway_method.post.http_method
  status_code       = aws_api_gateway_method_response.post_ok.status_code
  selection_pattern = "-"

  depends_on = [
    aws_api_gateway_integration.post
  ]
}

resource "aws_api_gateway_integration_response" "post_error_response" {
  rest_api_id       = aws_api_gateway_rest_api.api.id
  resource_id       = aws_api_gateway_rest_api.api.root_resource_id
  http_method       = aws_api_gateway_method.post.http_method
  status_code       = aws_api_gateway_method_response.post_error.status_code
  selection_pattern = "Invalid.*"

  response_templates = {
    "application/json" = <<EOF
{
  "message" : "$input.path('errorMessage')"
}
EOF
  }

  depends_on = [
    aws_api_gateway_integration.post
  ]
}
