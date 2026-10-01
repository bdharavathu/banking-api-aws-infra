variable "name" {
  type = string
}

variable "region" {
  type = string
}

variable "account_id" {
  type = string
}

variable "cidr_block" {
  type    = string
  default = "10.20.0.0/16"
}

variable "az_count" {
  type    = number
  default = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3."
  }
}

variable "enable_interface_endpoints" {
  type    = bool
  default = false
}

variable "logs_kms_key_arn" {
  type = string
}

variable "log_retention_days" {
  type    = number
  default = 30
}
