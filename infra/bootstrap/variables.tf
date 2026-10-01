variable "region" {
  type    = string
  default = "us-east-1"
}

variable "project" {
  type    = string
  default = "banking-api"
}

variable "github_repo" {
  description = "GitHub repository allowed to assume the CI roles, as owner/name."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repo))
    error_message = "github_repo must look like owner/name."
  }
}

variable "create_oidc_provider" {
  description = "Set to false if the account already has the GitHub Actions OIDC provider."
  type        = bool
  default     = true
}
