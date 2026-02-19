############################################
# Application URLs (Primary Access Points)
############################################

output "keycloak_url" {
  description = "URL for Keycloak admin console"
  value       = "https://${var.domain_name}"
}

output "keycloak_admin_console_url" {
  description = "URL for Keycloak admin console"
  value       = "https://${var.domain_name}/admin"
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.keycloak.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.keycloak.zone_id
}

############################################
# VPC & Networking
############################################

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "nat_gateway_ip" {
  description = "Public IP of the NAT Gateway"
  value       = aws_eip.nat.public_ip
}

############################################
# Security Groups
############################################

output "alb_security_group_id" {
  description = "Security group ID for the ALB"
  value       = aws_security_group.alb.id
}

output "ecs_tasks_security_group_id" {
  description = "Security group ID for ECS tasks"
  value       = aws_security_group.ecs_tasks.id
}

output "rds_security_group_id" {
  description = "Security group ID for RDS"
  value       = aws_security_group.rds.id
}

############################################
# ECS Cluster & Service
############################################

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.keycloak.name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.keycloak.arn
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.keycloak.name
}

output "ecs_task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = aws_ecs_task_definition.keycloak.arn
}

output "ecs_task_definition_family" {
  description = "Family of the ECS task definition"
  value       = aws_ecs_task_definition.keycloak.family
}

############################################
# Database Connection Info
############################################

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.keycloak.endpoint
}

output "rds_address" {
  description = "RDS instance address (hostname only)"
  value       = aws_db_instance.keycloak.address
}

output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.keycloak.port
}

output "rds_database_name" {
  description = "Name of the Keycloak database"
  value       = aws_db_instance.keycloak.db_name
}

output "rds_username" {
  description = "Master username for RDS"
  value       = aws_db_instance.keycloak.username
  sensitive   = true
}

output "rds_master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret containing RDS master credentials"
  value       = aws_db_instance.keycloak.master_user_secret[0].secret_arn
}

############################################
# Secrets Manager
############################################

output "keycloak_admin_secret_arn" {
  description = "ARN of the Secrets Manager secret containing Keycloak admin credentials"
  value       = aws_secretsmanager_secret.keycloak_admin.arn
}

############################################
# ACM Certificate
############################################

output "acm_certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = aws_acm_certificate.keycloak.arn
}

output "acm_certificate_domain_name" {
  description = "Domain name of the ACM certificate"
  value       = aws_acm_certificate.keycloak.domain_name
}

############################################
# CloudWatch Logs
############################################

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for Keycloak"
  value       = aws_cloudwatch_log_group.keycloak.name
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group for Keycloak"
  value       = aws_cloudwatch_log_group.keycloak.arn
}

############################################
# Service Discovery
############################################

output "service_discovery_namespace_id" {
  description = "ID of the service discovery namespace"
  value       = aws_service_discovery_private_dns_namespace.keycloak.id
}

output "service_discovery_namespace_name" {
  description = "Name of the service discovery namespace"
  value       = aws_service_discovery_private_dns_namespace.keycloak.name
}

output "service_discovery_service_arn" {
  description = "ARN of the service discovery service"
  value       = aws_service_discovery_service.keycloak.arn
}

############################################
# Bastion Host (For Database Access)
############################################

output "bastion_instance_id" {
  description = "Instance ID of the bastion host"
  value       = var.bastion_enabled ? aws_instance.bastion[0].id : null
}

output "bastion_private_ip" {
  description = "Private IP of the bastion host"
  value       = var.bastion_enabled ? aws_instance.bastion[0].private_ip : null
}

############################################
# IAM Roles
############################################

output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task role"
  value       = aws_iam_role.ecs_task.arn
}

############################################
# Target Group (For CI/CD Integration)
############################################

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.keycloak.arn
}

output "target_group_name" {
  description = "Name of the target group"
  value       = aws_lb_target_group.keycloak.name
}
