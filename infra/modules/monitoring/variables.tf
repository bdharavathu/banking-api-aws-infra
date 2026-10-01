variable "name" {
  type = string
}

variable "environment" {
  type = string
}

variable "region" {
  type = string
}

variable "account_id" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "alert_email" {
  type    = string
  default = ""
}

variable "app_log_group_name" {
  type = string
}

variable "alb_arn_suffix" {
  type = string
}

variable "target_group_arn_suffix" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "service_name" {
  type = string
}

variable "db_identifier" {
  type = string
}

variable "web_acl_name" {
  type    = string
  default = null
}
