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
