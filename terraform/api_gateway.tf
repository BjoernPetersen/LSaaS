resource "aws_api_gateway_rest_api" "api" {
  name = var.api_gateway_name

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_acm_certificate" "cert" {
  domain_name       = "${var.cloudflare_infix}.${var.cloudflare_zone_name}"
  validation_method = "DNS"
}

locals {
  domain_validation_option = one(aws_acm_certificate.cert.domain_validation_options)
}

resource "cloudflare_record" "cert_validation_record" {
  zone_id = var.cloudflare_zone_id
  name    = local.domain_validation_option.resource_record_name
  type    = local.domain_validation_option.resource_record_type
  value   = local.domain_validation_option.resource_record_value

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [cloudflare_record.cert_validation_record.hostname]
}

resource "aws_api_gateway_domain_name" "domain_name" {
  domain_name              = "${var.cloudflare_infix}.${var.cloudflare_zone_name}"
  regional_certificate_arn = aws_acm_certificate_validation.cert_validation.certificate_arn
  security_policy          = "TLS_1_2"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "cloudflare_record" "cert_record" {
  zone_id = var.cloudflare_zone_id
  name    = aws_api_gateway_domain_name.domain_name.domain_name
  type    = "CNAME"
  value   = aws_api_gateway_domain_name.domain_name.regional_domain_name
}

resource "aws_api_gateway_request_validator" "validate_body" {
  name                  = "validate_body"
  rest_api_id           = aws_api_gateway_rest_api.api.id
  validate_request_body = true
}

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = "prod"

  triggers = {
    redeployment = sha1(join(",", tolist([
      jsonencode(aws_api_gateway_integration.get),
      jsonencode(aws_api_gateway_integration.post)
    ])))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.get,
    aws_api_gateway_integration.post
  ]
}

resource "aws_api_gateway_usage_plan" "throttle" {
  name = "throttling"
  api_stages {
    api_id = aws_api_gateway_rest_api.api.id
    stage  = aws_api_gateway_deployment.deployment.stage_name
  }

  throttle_settings {
    burst_limit = 1
    rate_limit  = 1
  }
}

resource "aws_api_gateway_base_path_mapping" "api_domain" {
  api_id      = aws_api_gateway_rest_api.api.id
  domain_name = aws_api_gateway_domain_name.domain_name.domain_name
  stage_name  = aws_api_gateway_deployment.deployment.stage_name
}
