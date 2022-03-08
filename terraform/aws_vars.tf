variable "s3_bucket_name" {
  type    = string
  default = "lsaas2"
}

variable "function_name_prefix" {
  type    = string
  default = "lsaas2"
}

variable "cleanup_rule_name" {
  type    = string
  default = "lsaas2-cleanup"
}

variable "lambda_role_prefix" {
  type    = string
  default = "lsaas2-lambda"
}

variable "lambda_layer_name" {
  type    = string
  default = "lsaas2"
}

variable "api_gateway_name" {
  type    = string
  default = "lsaas2"
}
