terraform {
  backend "remote" {
    hostname = "app.terraform.io"
    organization = "BjoernPetersen"

    workspaces {
      name = "lsass"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0.0, < 5.0.0"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = ">= 3.0.0, < 4.0.0"
    }

    archive = {
      source="hashicorp/archive"
      version = ">= 2.0.0, < 3.0.0"
    }

    null = {
      source="hashicorp/null"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_token_tf
}

provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region
}

provider "archive" {}
provider "null" {}

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
  name_prefix        = var.lambda_role_prefix
  assume_role_policy = data.aws_iam_policy_document.assume_lambda_role_policy.json
}

data "aws_iam_policy_document" "lambda_logging" {
  statement {
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:CreateLogGroup"]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_policy" "lambda_logging" {
  name   = "lambda_logging"
  policy = data.aws_iam_policy_document.lambda_logging.json
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

data "aws_iam_policy_document" "lambda_role_s3_policy" {
  statement {
    actions   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.bucket.arn}/*"]
  }

  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.bucket.arn, "${aws_s3_bucket.bucket.arn}/*"]
  }
}

resource "aws_iam_role_policy" "lambda_role_s3_policy" {
  name_prefix = var.lambda_role_prefix
  role        = aws_iam_role.lambda_role.id

  policy = data.aws_iam_policy_document.lambda_role_s3_policy.json
}

resource "aws_lambda_function" "retrieve_cert" {
  function_name = "${var.function_name_prefix}-retrieveCert"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.8"
  handler       = "main.process_request"
  timeout       = 300

  filename         = "../code.zip"
  source_code_hash = filebase64sha256("../code.zip")

  layers = [aws_lambda_layer_version.lsaas.arn]

  environment {
    variables = {
      CLOUDFLARE_TOKEN        = var.cloudflare_token_lambda
      LE_ACCOUNT_KEY          = var.le_account_key
      LAMBDA_NAME_CONVERT_P12 = aws_lambda_function.convert_p12.function_name
      LAMBDA_NAME_CONVERT_JKS = aws_lambda_function.convert_jks.function_name
      S3_BUCKET_NAME          = aws_s3_bucket.bucket.id
    }
  }
}

data "aws_iam_policy_document" "lambda_role_invoke_policy" {
  statement {
    actions   = ["lambda:InvokeFunction", "lambda:InvokeAsync"]
    resources = [
      aws_lambda_function.convert_jks.arn,
      aws_lambda_function.convert_p12.arn,
      aws_lambda_function.retrieve_cert.arn
    ]
  }
}

resource "aws_iam_role_policy" "lambda_role_invoke_policy" {
  name_prefix = var.lambda_role_prefix
  role        = aws_iam_role.lambda_role.id

  policy = data.aws_iam_policy_document.lambda_role_invoke_policy.json
}

resource "aws_lambda_layer_version" "lsaas" {
  filename   = "../layer.zip"
  layer_name = var.lambda_layer_name

  compatible_runtimes = ["python3.8"]
}
