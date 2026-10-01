variable "name" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "keep_images" {
  type    = number
  default = 10
}

variable "force_delete" {
  type    = bool
  default = false
}
