resource "aws_lambda_function" "convert_jks" {
  function_name = "${var.function_name_prefix}-convertJKS"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "java11"
  handler       = "net.bjoernpetersen.lsass.jks.Main::handleRequest"
  timeout       = 15
  memory_size   = 256

  filename         = "../jks/build/libs/jks.jar"
  source_code_hash = filebase64sha256("../jks/build/libs/jks.jar")
}

resource "aws_lambda_function" "convert_p12" {
  function_name = "${var.function_name_prefix}-convertP12"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.8"
  handler       = "p12.convert_p12"
  timeout       = 30

  filename         = data.archive_file.code.output_path
  source_code_hash = data.archive_file.code.output_base64sha256

  layers = [aws_lambda_layer_version.lsaas.arn]
}
