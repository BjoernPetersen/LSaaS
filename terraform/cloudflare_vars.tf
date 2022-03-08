variable "cloudflare_zone_id" {
  type    = string
  default = "00f4ca020bbb420f7e5cb05483761e83"
}

variable "cloudflare_zone_name" {
  type    = string
  default = "kiu.party"
}

variable "cloudflare_token_lambda" {
  type      = string
  sensitive = true
}

variable "cloudflare_infix" {
  type    = string
  default = "instance"
}
