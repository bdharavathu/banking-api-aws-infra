variable "name" {
  type = string
}

variable "region" {
  type = string
}

variable "account_id" {
  type = string
}

variable "logs_kms_key_arn" {
  type = string
}

variable "enable_cloudtrail" {
  type    = bool
  default = true
}

variable "enable_guardduty" {
  type    = bool
  default = true
}

variable "enable_securityhub" {
  type    = bool
  default = false
}

variable "trail_retention_days" {
  type    = number
  default = 365
}

variable "force_destroy" {
  type    = bool
  default = false
}
