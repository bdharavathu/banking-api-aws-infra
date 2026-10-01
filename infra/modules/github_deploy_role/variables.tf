variable "name" {
  type = string
}

variable "region" {
  type = string
}

variable "account_id" {
  type = string
}

variable "github_repo" {
  type = string
}

variable "github_environment" {
  type    = string
  default = "production"
}

variable "build_branch" {
  type    = string
  default = "main"
}

variable "ecr_repository_arn" {
  type = string
}

variable "ecs_cluster_arn" {
  type = string
}

variable "ecs_cluster_name" {
  type = string
}

variable "ecs_service_arn" {
  type = string
}

variable "task_definition_family" {
  type = string
}

variable "task_role_arns" {
  type = list(string)
}

variable "ssm_prefix" {
  type = string
}

variable "api_client_key_secret_arn" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "app_log_group_arn" {
  type = string
}
