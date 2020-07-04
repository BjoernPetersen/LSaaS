terraform {
  backend "remote" {
    hostname = "app.terraform.io"

    workspaces {
      name = "lsass"
    }
  }
}

provider "cloudflare" {
    api_token = var.cloudflare_token_tf
}

provider "aws" {
  profile = "default"
  region  = var.aws_region
}

data "aws_iam_policy_document" "assume_lambda_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name_prefix = var.lambda_role_prefix
  assume_role_policy = data.aws_iam_policy_document.assume_lambda_role_policy.json
}

resource "aws_s3_bucket" "bucket" {
  bucket = var.s3_bucket_name
}

data "aws_iam_policy_document" "lambda_role_s3_policy" {
  statement {
    actions = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject", "s3:ListBucket"]
    resources = [ aws_s3_bucket.bucket.arn ]
  }
}

resource "aws_iam_role_policy" "lambda_role_s3_policy" {
  name_prefix = var.lambda_role_prefix
  role = aws_iam_role.lambda_role.id

  policy = data.aws_iam_policy_document.lambda_role_s3_policy.json
}

resource "aws_lambda_function" "retrieve_cert" {
  function_name = "${var.function_name_prefix}-retrieveCert"
  role = aws_iam_role.lambda_role.arn
  runtime = "python3.8"
  handler = "main.process_request"
  timeout = 300

  filename = "../code.zip"
  source_code_hash = filebase64sha256("../code.zip")

  layers = [ aws_lambda_layer_version.lsaas.arn ]

  environment {
    variables = {
      CLOUDFLARE_TOKEN = var.cloudflare_token_lambda
      LE_ACCOUNT_KEY = var.le_account_key
    }
  }
}

data "aws_iam_policy_document" "lambda_role_invoke_policy" {
  statement {
    actions = [ "lambda:InvokeFunction", "lambda:InvokeAsync" ]
    resources = [ 
      aws_lambda_function.convert_jks.arn,
      aws_lambda_function.convert_p12.arn,
      aws_lambda_function.retrieve_cert.arn
    ]
  }
}

resource "aws_iam_role_policy" "lambda_role_invoke_policy" {
  name_prefix = var.lambda_role_prefix
  role = aws_iam_role.lambda_role.id

  policy = data.aws_iam_policy_document.lambda_role_invoke_policy.json
}

resource "aws_lambda_layer_version" "lsaas" {
  filename = "../layer.zip"
  layer_name = var.lambda_layer_name

  compatible_runtimes = [ "python3.8" ]
}
