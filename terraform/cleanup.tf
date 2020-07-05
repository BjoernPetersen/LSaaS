resource "aws_lambda_function" "cleanup" {
  function_name = "${var.function_name_prefix}-cleanup"
  role = aws_iam_role.lambda_role.arn
  runtime = "python3.8"
  handler = "main.cleanup"
  timeout = 120

  filename = "../code.zip"
  source_code_hash = filebase64sha256("../code.zip")

  layers = [ aws_lambda_layer_version.lsaas.arn ]

  environment {
    variables = {
      CLOUDFLARE_TOKEN = var.cloudflare_token_lambda
      CLOUDFLARE_ZONE_ID = var.cloudflare_zone_id
      CLOUDFLARE_INFIX = var.cloudflare_infix
      CLOUDFLARE_ZONE_NAME = var.cloudflare_zone_name
    }
  }
}

resource "aws_cloudwatch_event_rule" "cleanup" {
  name        = var.cleanup_rule_name
  schedule_expression = "rate(1 day)"
}

resource "aws_cloudwatch_event_target" "cleanup" {
  rule      = aws_cloudwatch_event_rule.cleanup.name
  arn       = aws_lambda_function.cleanup.arn
}

resource "aws_lambda_permission" "invoke_cleanup" {
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.cleanup.function_name
    principal = "events.amazonaws.com"
    source_arn = aws_cloudwatch_event_rule.cleanup.arn
}
