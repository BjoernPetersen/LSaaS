
resource "aws_api_gateway_method" "get_old" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_rest_api.api.root_resource_id
  http_method = "GET"
  authorization = "NONE"
  request_validator_id = aws_api_gateway_request_validator.validate_body.id

  request_models = {
    "application/json" = aws_api_gateway_model.result_request.name
  }
}

resource "aws_api_gateway_method_response" "get_old_ok" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_rest_api.api.root_resource_id
  http_method = aws_api_gateway_method.get_old.http_method
  status_code = "200"

  response_models = {
    "application/json" = aws_api_gateway_model.result_response.name
  }
}

resource "aws_api_gateway_integration_response" "old_result_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_rest_api.api.root_resource_id
  http_method = aws_api_gateway_method.get_old.http_method
  status_code = aws_api_gateway_method_response.get_ok.status_code

  depends_on = [
    aws_api_gateway_integration.get_old
  ]
}

resource "aws_api_gateway_integration" "get_old" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_rest_api.api.root_resource_id
  http_method = aws_api_gateway_method.get_old.http_method
  integration_http_method = "POST"
  type = "AWS"
  uri = aws_lambda_function.get_result.invoke_arn
}
