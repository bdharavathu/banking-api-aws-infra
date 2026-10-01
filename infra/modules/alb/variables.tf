variable "name" {
  type = string
}

variable "account_id" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}

variable "app_port" {
  type    = number
  default = 8000
}

variable "health_check_path" {
  type    = string
  default = "/health"
}

variable "domain_name" {
  description = "Custom domain for the API. Empty uses a self-signed certificate on the ALB DNS name."
  type        = string
  default     = ""
}

variable "route53_zone_id" {
  type    = string
  default = ""
}

variable "enable_waf" {
  type    = bool
  default = true
}

variable "waf_rate_limit" {
  description = "Max requests per IP per 5 minutes."
  type        = number
  default     = 1000
}

variable "logs_kms_key_arn" {
  type = string
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "access_log_retention_days" {
  type    = number
  default = 90
}

variable "deletion_protection" {
  type    = bool
  default = false
}

variable "force_destroy" {
  type    = bool
  default = false
}
