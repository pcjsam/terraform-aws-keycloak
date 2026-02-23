############################################
# Basic Keycloak Deployment Example
############################################
#
# This example demonstrates a minimal Keycloak deployment
# suitable for development and testing environments.
#
# Features:
# - Single-AZ RDS (no Multi-AZ)
# - 2 Keycloak tasks for basic HA
# - Minimal resource allocation
# - Auto-generated admin password
#

module "keycloak" {
  source = "../../"

  # Pass both providers to the module
  providers = {
    aws     = aws
    aws.dns = aws.dns
  }

  project_name    = var.project_name
  domain_name     = var.domain_name
  route53_zone_id = var.route53_zone_id

  # VPC Configuration (using defaults)
  vpc_cidr                 = "10.0.0.0/16"
  vpc_public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  vpc_private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]

  # Keycloak Configuration (minimal for dev)
  keycloak_image         = var.keycloak_image
  keycloak_task_cpu      = 1024 # 1 vCPU
  keycloak_task_memory   = 2048 # 2 GB
  keycloak_desired_count = 2
  keycloak_min_capacity  = 1
  keycloak_max_capacity  = 4

  # RDS Configuration (minimal for dev)
  rds_instance_class          = "db.t3.micro"
  rds_allocated_storage       = 20
  rds_multi_az                = false
  rds_backup_retention_period = 1
  rds_deletion_protection     = false
  rds_skip_final_snapshot     = true

  # Logging
  log_retention_days = 7

  tags = var.tags
}
