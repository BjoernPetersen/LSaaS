resource "aws_lambda_function" "post" {
  function_name = "${var.function_name_prefix}-post"
  role = aws_iam_role.lambda_role.arn
  runtime = "python3.8"
  handler = "main.post_request"
  timeout = 30

  filename = "../code.zip"
  source_code_hash = filebase64sha256("../code.zip")

  layers = [ aws_lambda_layer_version.lsaas.arn ]

  environment {
    variables = {
      CLOUDFLARE_TOKEN = var.cloudflare_token_lambda
      CLOUDFLARE_ZONE_ID = var.cloudflare_zone_id
      CLOUDFLARE_ZONE_NAME = var.cloudflare_zone_name
      CLOUDFLARE_INFIX = var.cloudflare_infix
      LAMBDA_NAME_RETRIEVE = aws_lambda_function.retrieve_cert.function_name
    }
  }
}

resource "aws_lambda_function" "get_result" {
  function_name = "${var.function_name_prefix}-getResult"
  role = aws_iam_role.lambda_role.arn
  runtime = "python3.8"
  handler = "main.get_result"
  timeout = 30

  filename = "../code.zip"
  source_code_hash = filebase64sha256("../code.zip")

  layers = [ aws_lambda_layer_version.lsaas.arn ]

  environment {
    variables = {
      S3_BUCKET_NAME = aws_s3_bucket.bucket.id
    }
  }
}

resource "aws_api_gateway_rest_api" "api" {
  name = var.api_gateway_name

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_acm_certificate" "cert" {
  domain_name = "${var.cloudflare_infix}.${var.cloudflare_zone_name}"
  validation_method = "DNS"
}

resource "cloudflare_record" "cert_validation_record" {
  zone_id = var.cloudflare_zone_id
  name = aws_acm_certificate.cert.domain_validation_options.0.resource_record_name
  type = aws_acm_certificate.cert.domain_validation_options.0.resource_record_type
  value = aws_acm_certificate.cert.domain_validation_options.0.resource_record_value

  lifecycle {
    ignore_changes = [ value ]
  }
}

resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn = aws_acm_certificate.cert.arn
  validation_record_fqdns = [ cloudflare_record.cert_validation_record.hostname ]
}

resource "aws_api_gateway_domain_name" "domain_name" {
  domain_name = "${var.cloudflare_infix}.${var.cloudflare_zone_name}"
  regional_certificate_arn = aws_acm_certificate_validation.cert_validation.certificate_arn
  security_policy = "TLS_1_2"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "cloudflare_record" "cert_record" {
  zone_id = var.cloudflare_zone_id
  name = aws_api_gateway_domain_name.domain_name.domain_name
  type = "CNAME"
  value = aws_api_gateway_domain_name.domain_name.regional_domain_name
}

resource "aws_api_gateway_request_validator" "validate_body" {
  name                        = "validate_body"
  rest_api_id                 = aws_api_gateway_rest_api.api.id
  validate_request_body       = true
}

resource "aws_api_gateway_method" "get" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_rest_api.api.root_resource_id
  http_method = "GET"
  authorization = "NONE"
  request_validator_id = aws_api_gateway_request_validator.validate_body.id

  request_models = {
    "application/json" = aws_api_gateway_model.result_request.name
  }
}

resource "aws_api_gateway_integration" "get" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_rest_api.api.root_resource_id
  http_method = aws_api_gateway_method.get.http_method
  integration_http_method = "POST"
  type = "AWS"
  uri = aws_lambda_function.get_result.invoke_arn
}

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name = "prod"

  triggers = {
    redeployment = sha1(join(",", list(
      jsonencode(aws_api_gateway_integration.get),
    )))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.get
  ]
}

resource "aws_api_gateway_base_path_mapping" "api_domain" {
  api_id = aws_api_gateway_rest_api.api.id
  domain_name = aws_api_gateway_domain_name.domain_name.domain_name
  stage_name = aws_api_gateway_deployment.deployment.stage_name
}

# resource "aws_apigatewayv2_integration" "post" {
#   api_id = aws_apigatewayv2_api.api.id
#   integration_type = "AWS"
#   content_handling_strategy = "CONVERT_TO_TEXT"
#   integration_method = "POST"
#   integration_uri = aws_lambda_function.post.invoke_arn
# }
