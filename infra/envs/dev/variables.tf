variable "region" {
  type    = string
  default = "us-east-1"
}

variable "project" {
  type    = string
  default = "banking-api"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "github_repo" {
  description = "owner/name of the GitHub repository that deploys this stack."
  type        = string
}

variable "alert_email" {
  description = "Email subscribed to alarm notifications. Leave empty to skip."
  type        = string
  default     = ""
}

variable "allowed_ingress_cidrs" {
  description = "CIDRs allowed to reach the ALB. Narrow this to your IP for a private demo."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "domain_name" {
  type    = string
  default = ""
}

variable "route53_zone_id" {
  type    = string
  default = ""
}

variable "image_tag" {
  description = "Initial image tag. Later deploys come from the pipeline."
  type        = string
  default     = "bootstrap"
}

variable "app_desired_count" {
  type    = number
  default = 2
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "db_multi_az" {
  type    = bool
  default = false
}

variable "enable_waf" {
  type    = bool
  default = true
}

variable "enable_interface_endpoints" {
  type    = bool
  default = false
}

variable "enable_cloudtrail" {
  type    = bool
  default = false
}

variable "enable_guardduty" {
  description = "Set to false if GuardDuty is already enabled in this account/region."
  type        = bool
  default     = true
}

variable "enable_securityhub" {
  type    = bool
  default = false
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "ephemeral" {
  description = "Demo mode: allows terraform destroy to remove data (no deletion protection, no final snapshot, buckets force-destroyed)."
  type        = bool
  default     = true
}
