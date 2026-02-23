############################################
# Application Access
############################################

output "keycloak_url" {
  description = "URL for Keycloak"
  value       = module.keycloak.keycloak_url
}

############################################
# Secrets Management
############################################

output "keycloak_admin_secret_arn" {
  description = "ARN of the Secrets Manager secret containing Keycloak admin credentials"
  value       = module.keycloak.keycloak_admin_secret_arn
}

output "rds_master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret containing RDS master credentials"
  value       = module.keycloak.rds_master_user_secret_arn
}

############################################
# ECS (for deployments)
############################################

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.keycloak.ecs_cluster_name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = module.keycloak.ecs_service_name
}

############################################
# Database
############################################

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = module.keycloak.rds_endpoint
}

############################################
# Monitoring & Logging
############################################

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for Keycloak logs"
  value       = module.keycloak.cloudwatch_log_group_name
}

############################################
# Database Access
############################################

output "bastion_instance_id" {
  description = "Instance ID of the bastion host (for SSM Session Manager)"
  value       = module.keycloak.bastion_instance_id
}
