variable "name" {
  type = string
}

variable "region" {
  type = string
}

variable "account_id" {
  type = string
}

variable "deletion_window_in_days" {
  type    = number
  default = 7
}
