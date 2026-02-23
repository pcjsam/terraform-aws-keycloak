############################################
# Production Keycloak Deployment Example
############################################
#
# This example demonstrates a production-ready Keycloak deployment
# with high availability, security, and monitoring features.
#
# Features:
# - Multi-AZ RDS with deletion protection
# - 3+ Keycloak tasks with auto-scaling
# - VPC Flow Logs enabled
# - ALB access logs enabled
# - Container Insights with enhanced observability (task-level metrics)
# - Performance Insights enabled
# - Bastion host for database access
# - Extended log retention
#

module "keycloak" {
  source = "../../"

  # Pass providers to the module
  # aws.dns is configured to assume a role in the DNS account
  providers = {
    aws     = aws
    aws.dns = aws.dns
  }

  project_name    = var.project_name
  domain_name     = var.domain_name
  route53_zone_id = var.route53_zone_id

  # VPC Configuration (3 AZs for production)
  vpc_cidr                     = var.vpc_cidr
  vpc_public_subnet_cidrs      = var.vpc_public_subnet_cidrs
  vpc_private_subnet_cidrs     = var.vpc_private_subnet_cidrs
  vpc_enable_flow_logs         = true
  vpc_flow_logs_retention_days = 30

  # ALB Configuration
  alb_access_logs_enabled = true
  alb_idle_timeout        = 120

  # ECS Configuration
  ecs_container_insights_enabled = true # Enhanced observability with task-level metrics

  # Keycloak Task Configuration (production sizing)
  keycloak_image                            = var.keycloak_image
  keycloak_cross_account_ecr_repository_arn = var.keycloak_cross_account_ecr_repository_arn
  keycloak_task_cpu                         = 2048 # 2 vCPUs
  keycloak_task_memory                      = 4096 # 4 GB
  keycloak_desired_count                    = 3
  keycloak_min_capacity                     = 2
  keycloak_max_capacity                     = 10

  # Auto-scaling thresholds
  keycloak_autoscaling_cpu_target    = 60
  keycloak_autoscaling_memory_target = 70

  # Keycloak Application Configuration
  keycloak_hostname_strict = true
  keycloak_log_level       = "INFO"

  # Health Check Configuration
  health_check_path                = "/health/ready"
  health_check_interval            = 30
  health_check_timeout             = 10
  health_check_healthy_threshold   = 2
  health_check_unhealthy_threshold = 3

  # RDS Configuration (production)
  rds_instance_class                 = var.rds_instance_class
  rds_allocated_storage              = var.rds_allocated_storage
  rds_max_allocated_storage          = var.rds_max_allocated_storage
  rds_multi_az                       = true
  rds_backup_retention_period        = 14
  rds_deletion_protection            = true
  rds_skip_final_snapshot            = false
  rds_storage_encrypted              = true
  rds_performance_insights_enabled   = true
  rds_performance_insights_retention = 7

  # Logging
  log_retention_days = 90

  # Bastion Host (for database access)
  bastion_enabled             = true
  bastion_instance_type       = "t3.micro"
  bastion_allowed_cidr_blocks = var.bastion_allowed_cidr_blocks

  tags = var.tags
}

############################################
# Keycloak Realm Configuration (Optional)
############################################
#
# Use the Keycloak Terraform provider to manage realms,
# clients, and users as code.
#

# Uncomment to enable realm management
# provider "keycloak" {
#   client_id = "admin-cli"
#   username  = jsondecode(data.aws_secretsmanager_secret_version.keycloak_admin.secret_string)["username"]
#   password  = jsondecode(data.aws_secretsmanager_secret_version.keycloak_admin.secret_string)["password"]
#   url       = module.keycloak.keycloak_url
# }

# data "aws_secretsmanager_secret_version" "keycloak_admin" {
#   secret_id = module.keycloak.keycloak_admin_secret_arn
# }

# resource "keycloak_realm" "main" {
#   realm   = "my-application"
#   enabled = true
#
#   login_theme   = "keycloak"
#   account_theme = "keycloak.v2"
#
#   access_token_lifespan = "5m"
#
#   security_defenses {
#     brute_force_detection {
#       permanent_lockout           = false
#       max_login_failures          = 30
#       wait_increment_seconds      = 60
#       quick_login_check_milli_sec = 1000
#       minimum_quick_login_wait    = 60
#       max_failure_wait_seconds    = 900
#       failure_reset_time_seconds  = 43200
#     }
#   }
# }
