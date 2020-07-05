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

resource "aws_apigatewayv2_api" "api" {
  name = var.api_gateway_name
  protocol_type = "HTTP"
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
}

resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn = aws_acm_certificate.cert.arn
  validation_record_fqdns = [ cloudflare_record.cert_validation_record.hostname ]
}

resource "aws_apigatewayv2_domain_name" "domain_name" {
  domain_name = "${var.cloudflare_infix}.${var.cloudflare_zone_name}"

  domain_name_configuration {
    certificate_arn = aws_acm_certificate_validation.cert_validation.certificate_arn
    endpoint_type = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource "cloudflare_record" "cert_record" {
  zone_id = var.cloudflare_zone_id
  name = aws_apigatewayv2_domain_name.domain_name.domain_name
  type = "CNAME"
  value = aws_apigatewayv2_domain_name.domain_name.domain_name_configuration.0.target_domain_name
}

resource "aws_apigatewayv2_stage" "prod" {
  api_id = aws_apigatewayv2_api.api.id
  name = "prod"
}

resource "aws_apigatewayv2_api_mapping" "api_domain" {
  api_id = aws_apigatewayv2_api.api.id
  domain_name = aws_apigatewayv2_domain_name.domain_name.id
  stage = aws_apigatewayv2_stage.prod.id
}

# resource "aws_apigatewayv2_integration" "post" {
#   api_id = aws_apigatewayv2_api.api.id
#   integration_type = "AWS"
#   content_handling_strategy = "CONVERT_TO_TEXT"
#   integration_method = "POST"
#   integration_uri = aws_lambda_function.post.invoke_arn
# }

# resource "aws_apigatewayv2_integration" "get" {
#   api_id = aws_apigatewayv2_api.api.id
#   integration_type = "AWS"
#   content_handling_strategy = "CONVERT_TO_TEXT"
#   integration_method = "GET"
#   integration_uri = aws_lambda_function.get_result.invoke_arn
# }
