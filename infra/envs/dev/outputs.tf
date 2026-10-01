output "api_url" {
  value = module.alb.api_url
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "ecs_cluster" {
  value = module.app.cluster_name
}

output "ecs_service" {
  value = module.app.service_name
}

output "api_client_key_secret_arn" {
  value = module.app.api_client_key_secret_arn
}

output "github_app_build_role_arn" {
  value = module.github_deploy_role.build_role_arn
}

output "github_app_deploy_role_arn" {
  value = module.github_deploy_role.deploy_role_arn
}

output "dashboard_url" {
  value = module.monitoring.dashboard_url
}

output "alerts_topic_arn" {
  value = module.monitoring.alerts_topic_arn
}

output "deploy_parameters_path" {
  value = local.ssm_prefix
}
