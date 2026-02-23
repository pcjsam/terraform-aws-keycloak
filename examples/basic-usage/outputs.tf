############################################
# Outputs
############################################

output "keycloak_url" {
  description = "URL for Keycloak"
  value       = module.keycloak.keycloak_url
}

output "keycloak_admin_secret_arn" {
  description = "ARN of the Secrets Manager secret containing Keycloak admin credentials"
  value       = module.keycloak.keycloak_admin_secret_arn
}

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = module.keycloak.rds_endpoint
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.keycloak.ecs_cluster_name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = module.keycloak.ecs_service_name
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = module.keycloak.cloudwatch_log_group_name
}
