data "aws_caller_identity" "current" {}

locals {
  name       = "${var.project}-${var.environment}"
  account_id = data.aws_caller_identity.current.account_id
  ssm_prefix = "/${var.project}/${var.environment}/deploy"
  app_port   = 8000
}

module "kms" {
  source     = "../../modules/kms"
  name       = local.name
  region     = var.region
  account_id = local.account_id
}

module "network" {
  source                     = "../../modules/network"
  name                       = local.name
  region                     = var.region
  account_id                 = local.account_id
  enable_interface_endpoints = var.enable_interface_endpoints
  logs_kms_key_arn           = module.kms.logs_key_arn
  log_retention_days         = var.log_retention_days
}

module "security_groups" {
  source                = "../../modules/security_groups"
  name                  = local.name
  vpc_id                = module.network.vpc_id
  app_port              = local.app_port
  allowed_ingress_cidrs = var.allowed_ingress_cidrs
}

module "alb" {
  source             = "../../modules/alb"
  name               = local.name
  account_id         = local.account_id
  vpc_id             = module.network.vpc_id
  public_subnet_ids  = module.network.public_subnet_ids
  security_group_id  = module.security_groups.alb_sg_id
  app_port           = local.app_port
  domain_name        = var.domain_name
  route53_zone_id    = var.route53_zone_id
  enable_waf         = var.enable_waf
  logs_kms_key_arn   = module.kms.logs_key_arn
  log_retention_days = var.log_retention_days
  force_destroy      = var.ephemeral
}

module "database" {
  source              = "../../modules/database"
  name                = local.name
  subnet_ids          = module.network.database_subnet_ids
  security_group_id   = module.security_groups.db_sg_id
  kms_key_arn         = module.kms.data_key_arn
  logs_kms_key_arn    = module.kms.logs_key_arn
  instance_class      = var.db_instance_class
  multi_az            = var.db_multi_az
  deletion_protection = !var.ephemeral
  skip_final_snapshot = var.ephemeral
  apply_immediately   = var.ephemeral
  log_retention_days  = var.log_retention_days
}

module "ecr" {
  source       = "../../modules/ecr"
  name         = local.name
  kms_key_arn  = module.kms.data_key_arn
  force_delete = var.ephemeral
}

module "app" {
  source                      = "../../modules/ecs_service"
  name                        = local.name
  environment                 = var.environment
  region                      = var.region
  account_id                  = local.account_id
  subnet_ids                  = module.network.private_subnet_ids
  security_group_id           = module.security_groups.app_sg_id
  target_group_arn            = module.alb.target_group_arn
  alb_resource_label          = "${module.alb.alb_arn_suffix}/${module.alb.target_group_arn_suffix}"
  ecr_repository_url          = module.ecr.repository_url
  ecr_repository_arn          = module.ecr.repository_arn
  image_tag                   = var.image_tag
  app_port                    = local.app_port
  desired_count               = var.app_desired_count
  db_host                     = module.database.address
  db_port                     = module.database.port
  db_name                     = module.database.db_name
  db_secret_arn               = module.database.master_secret_arn
  kms_key_arn                 = module.kms.data_key_arn
  logs_kms_key_arn            = module.kms.logs_key_arn
  log_retention_days          = var.log_retention_days
  secret_recovery_window_days = var.ephemeral ? 0 : 7

  depends_on = [module.alb]
}

module "monitoring" {
  source                  = "../../modules/monitoring"
  name                    = local.name
  environment             = var.environment
  region                  = var.region
  account_id              = local.account_id
  kms_key_arn             = module.kms.data_key_arn
  alert_email             = var.alert_email
  app_log_group_name      = module.app.log_group_name
  alb_arn_suffix          = module.alb.alb_arn_suffix
  target_group_arn_suffix = module.alb.target_group_arn_suffix
  cluster_name            = module.app.cluster_name
  service_name            = module.app.service_name
  db_identifier           = module.database.identifier
  web_acl_name            = module.alb.web_acl_name
}

module "audit" {
  source             = "../../modules/audit"
  name               = local.name
  region             = var.region
  account_id         = local.account_id
  logs_kms_key_arn   = module.kms.logs_key_arn
  enable_cloudtrail  = var.enable_cloudtrail
  enable_guardduty   = var.enable_guardduty
  enable_securityhub = var.enable_securityhub
  force_destroy      = var.ephemeral
}

module "github_deploy_role" {
  source                    = "../../modules/github_deploy_role"
  name                      = local.name
  region                    = var.region
  account_id                = local.account_id
  github_repo               = var.github_repo
  ecr_repository_arn        = module.ecr.repository_arn
  ecs_cluster_arn           = module.app.cluster_arn
  ecs_cluster_name          = module.app.cluster_name
  ecs_service_arn           = module.app.service_arn
  task_definition_family    = module.app.task_definition_family
  task_role_arns            = [module.app.execution_role_arn, module.app.task_role_arn]
  ssm_prefix                = local.ssm_prefix
  api_client_key_secret_arn = module.app.api_client_key_secret_arn
  kms_key_arn               = module.kms.data_key_arn
  app_log_group_arn         = module.app.log_group_arn
}

resource "aws_ssm_parameter" "deploy" {
  for_each = {
    cluster                   = module.app.cluster_name
    service                   = module.app.service_name
    task_family               = module.app.task_definition_family
    container_name            = module.app.container_name
    subnets                   = join(",", module.network.private_subnet_ids)
    security_group            = module.security_groups.app_sg_id
    ecr_repository_url        = module.ecr.repository_url
    log_group                 = module.app.log_group_name
    api_url                   = module.alb.api_url
    api_client_key_secret_arn = module.app.api_client_key_secret_arn
  }

  name   = "${local.ssm_prefix}/${each.key}"
  type   = "SecureString"
  key_id = module.kms.data_key_arn
  value  = each.value
}
