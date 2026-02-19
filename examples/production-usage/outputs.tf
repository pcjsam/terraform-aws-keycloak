############################################
# Application Access
############################################

output "keycloak_url" {
  description = "URL for Keycloak"
  value       = module.keycloak.keycloak_url
}

output "keycloak_admin_console_url" {
  description = "URL for Keycloak admin console"
  value       = module.keycloak.keycloak_admin_console_url
}

output "alb_dns_name" {
  description = "DNS name of the ALB (for external DNS if needed)"
  value       = module.keycloak.alb_dns_name
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
# Infrastructure Details
############################################

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.keycloak.vpc_id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.keycloak.ecs_cluster_name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = module.keycloak.ecs_service_name
}

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

output "database_connection_command" {
  description = "Command to connect to the database via bastion"
  value       = module.keycloak.bastion_instance_id != null ? "aws ssm start-session --target ${module.keycloak.bastion_instance_id}" : "Bastion not enabled"
}

############################################
# CI/CD Integration
############################################

output "ecs_task_definition_family" {
  description = "ECS task definition family (for CI/CD pipelines)"
  value       = module.keycloak.ecs_task_definition_family
}

output "target_group_arn" {
  description = "Target group ARN (for CI/CD integrations)"
  value       = module.keycloak.target_group_arn
}
