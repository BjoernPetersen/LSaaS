resource "aws_lambda_function" "convert_jks" {
  function_name = "${var.function_name_prefix}-convertJKS"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "java11"
  handler       = "net.bjoernpetersen.lsass.jks.Main::handleRequest"
  timeout       = 15
  memory_size   = 256

  filename         = "../jks/build/libs/jks.jar"
  source_code_hash = filebase64sha256("../jks/build/libs/jks.jar")

  environment {
    variables = {
      SENTRY_DSN = var.sentry_dsn
    }
  }
}

resource "aws_lambda_function" "convert_p12" {
  function_name = "${var.function_name_prefix}-convertP12"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.9"
  handler       = "p12.convert_p12"
  timeout       = 30

  filename         = "../code.zip"
  source_code_hash = filebase64sha256("../code.zip")

  layers = [aws_lambda_layer_version.lsaas.arn]

  environment {
    variables = {
      SENTRY_DSN = var.sentry_dsn
    }
  }
}
