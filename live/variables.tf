variable "s3_endpoint" {
  description = "S3 endpoint of the local emulator."
  type        = string
  default     = "http://127.0.0.1:5100"
}

variable "expiration_days" {
  type    = number
  default = null
}

variable "block_public_access" {
  type    = bool
  default = true
}

variable "extra_tags" {
  type    = map(string)
  default = {}
}
