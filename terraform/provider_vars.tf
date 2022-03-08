variable "aws_profile" {
  type = string
  default = "default"
}

variable "aws_region" {
  type = string
  default = "eu-central-1"
}

variable "cloudflare_token_tf" {
  type = string
  sensitive = true
}
