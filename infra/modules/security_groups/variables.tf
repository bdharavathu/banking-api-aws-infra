variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "app_port" {
  type    = number
  default = 8000
}

variable "allowed_ingress_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "enable_interface_endpoints" {
  type    = bool
  default = false
}

variable "endpoints_security_group_id" {
  type    = string
  default = null
}

variable "s3_prefix_list_id" {
  type    = string
  default = null
}
