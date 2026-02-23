############################################
# Application Access
############################################

output "keycloak_url" {
  description = "URL for Keycloak"
  value       = "https://${var.domain_name}"
}

############################################
# ECS (for deployments and CLI commands)
############################################

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.keycloak.name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.keycloak.name
}

############################################
# Secrets (for retrieving credentials)
############################################

output "keycloak_admin_secret_arn" {
  description = "ARN of the Secrets Manager secret containing Keycloak admin credentials"
  value       = aws_secretsmanager_secret.keycloak_admin.arn
}

output "rds_master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret containing RDS master credentials"
  value       = aws_db_instance.keycloak.master_user_secret[0].secret_arn
}

############################################
# Database
############################################

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.keycloak.endpoint
}

############################################
# Logs
############################################

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for Keycloak"
  value       = aws_cloudwatch_log_group.keycloak.name
}

############################################
# Bastion (for database access)
############################################

output "bastion_instance_id" {
  description = "Instance ID of the bastion host (use with SSM Session Manager)"
  value       = var.bastion_enabled ? aws_instance.bastion[0].id : null
}
