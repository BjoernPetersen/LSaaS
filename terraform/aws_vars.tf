variable "s3_bucket_name" {
  default = "lsaas2"
}

variable "function_name_prefix" {
  default = "lsaas2"
}

variable "cleanup_rule_name" {
  default = "lsaas2-cleanup"
}

variable "lambda_role_prefix" {
  default = "lsaas2-lambda"
}

variable "lambda_layer_name" {
  default = "lsaas2"
}

variable "api_gateway_name" {
  default = "lsaas2"
}