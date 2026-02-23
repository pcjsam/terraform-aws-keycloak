############################################
# General Configuration
############################################

variable "project_name" {
  description = "Name of the project, used as prefix for all resources"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.project_name))
    error_message = "Project name must start with a letter and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

############################################
# VPC Configuration
############################################

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid CIDR block."
  }
}

variable "vpc_public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (minimum 2 for ALB)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]

  validation {
    condition     = length(var.vpc_public_subnet_cidrs) >= 2
    error_message = "At least 2 public subnets are required for ALB high availability."
  }
}

variable "vpc_private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (minimum 2 for RDS and ECS)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]

  validation {
    condition     = length(var.vpc_private_subnet_cidrs) >= 2
    error_message = "At least 2 private subnets are required for RDS and ECS high availability."
  }
}

variable "vpc_availability_zones" {
  description = "Availability zones for subnets"
  type        = list(string)
  default     = []
}

variable "vpc_enable_flow_logs" {
  description = "Enable VPC flow logs for network monitoring"
  type        = bool
  default     = false
}

variable "vpc_flow_logs_retention_days" {
  description = "Number of days to retain VPC flow logs"
  type        = number
  default     = 14

  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.vpc_flow_logs_retention_days)
    error_message = "Flow logs retention days must be a valid CloudWatch Logs retention period."
  }
}

############################################
# ALB Configuration
############################################

variable "alb_internal" {
  description = "Whether the ALB is internal (true) or internet-facing (false)"
  type        = bool
  default     = false
}

variable "alb_idle_timeout" {
  description = "Time in seconds that the connection is allowed to be idle"
  type        = number
  default     = 60

  validation {
    condition     = var.alb_idle_timeout >= 1 && var.alb_idle_timeout <= 4000
    error_message = "ALB idle timeout must be between 1 and 4000 seconds."
  }
}

variable "alb_access_logs_enabled" {
  description = "Enable ALB access logs to S3"
  type        = bool
  default     = false
}

variable "alb_access_logs_bucket_name" {
  description = "S3 bucket name for ALB access logs (auto-generated if empty)"
  type        = string
  default     = ""
}

variable "alb_ssl_policy" {
  description = "SSL policy for HTTPS listener"
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

############################################
# ACM Certificate Configuration
############################################

variable "domain_name" {
  description = "Primary domain name for Keycloak (e.g., auth.example.com)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]*[a-z0-9]$", var.domain_name))
    error_message = "Domain name must be a valid DNS name."
  }
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for DNS validation and record creation"
  type        = string
}

############################################
# ECS Cluster Configuration
############################################

variable "ecs_container_insights_enabled" {
  description = "Enable CloudWatch Container Insights for ECS cluster"
  type        = bool
  default     = true
}

############################################
# Keycloak Task Configuration
############################################

variable "keycloak_image" {
  description = "Docker image for Keycloak. Specify the full image URI including tag (e.g., quay.io/keycloak/keycloak:26.0.6 or 123456789.dkr.ecr.us-east-1.amazonaws.com/keycloak:26.0.6)"
  type        = string
  default     = "quay.io/keycloak/keycloak:26.0.6"
}

variable "keycloak_cross_account_ecr_repository_arn" {
  description = "ECR repository ARN from another AWS account that the ECS task execution role needs to pull images from. Example: 'arn:aws:ecr:us-east-1:123456789012:repository/keycloak'. Leave empty if using same-account ECR or public registry."
  type        = string
  default     = ""
}

variable "keycloak_task_cpu" {
  description = "CPU units for Keycloak task (1024 = 1 vCPU)"
  type        = number
  default     = 1024

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096, 8192, 16384], var.keycloak_task_cpu)
    error_message = "Task CPU must be a valid Fargate CPU value: 256, 512, 1024, 2048, 4096, 8192, or 16384."
  }
}

variable "keycloak_task_memory" {
  description = "Memory in MB for Keycloak task"
  type        = number
  default     = 2048

  validation {
    condition     = var.keycloak_task_memory >= 512 && var.keycloak_task_memory <= 122880
    error_message = "Task memory must be between 512 MB and 122880 MB."
  }
}

variable "keycloak_desired_count" {
  description = "Desired number of Keycloak tasks (minimum 2 for HA)"
  type        = number
  default     = 2

  validation {
    condition     = var.keycloak_desired_count >= 1
    error_message = "Desired count must be at least 1."
  }
}

variable "keycloak_min_capacity" {
  description = "Minimum number of Keycloak tasks for auto-scaling"
  type        = number
  default     = 2
}

variable "keycloak_max_capacity" {
  description = "Maximum number of Keycloak tasks for auto-scaling"
  type        = number
  default     = 10
}

variable "keycloak_autoscaling_cpu_target" {
  description = "Target CPU utilization percentage for auto-scaling"
  type        = number
  default     = 70

  validation {
    condition     = var.keycloak_autoscaling_cpu_target >= 10 && var.keycloak_autoscaling_cpu_target <= 100
    error_message = "CPU target must be between 10 and 100 percent."
  }
}

variable "keycloak_autoscaling_memory_target" {
  description = "Target memory utilization percentage for auto-scaling"
  type        = number
  default     = 80

  validation {
    condition     = var.keycloak_autoscaling_memory_target >= 10 && var.keycloak_autoscaling_memory_target <= 100
    error_message = "Memory target must be between 10 and 100 percent."
  }
}

variable "keycloak_http_port" {
  description = "HTTP port for Keycloak"
  type        = number
  default     = 8080
}

variable "keycloak_health_port" {
  description = "Health check port for Keycloak"
  type        = number
  default     = 9000
}

variable "keycloak_jgroups_port" {
  description = "JGroups port for Keycloak cluster communication"
  type        = number
  default     = 7800
}

############################################
# Keycloak Application Configuration
############################################

variable "keycloak_admin_username" {
  description = "Keycloak admin username"
  type        = string
  default     = "admin"
}

variable "keycloak_admin_password" {
  description = "Keycloak admin password (stored in Secrets Manager, auto-generated if empty)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "keycloak_hostname_strict" {
  description = "Enable strict hostname checking"
  type        = bool
  default     = true
}

variable "keycloak_log_level" {
  description = "Keycloak log level"
  type        = string
  default     = "INFO"

  validation {
    condition     = contains(["ALL", "DEBUG", "ERROR", "FATAL", "INFO", "OFF", "TRACE", "WARN"], var.keycloak_log_level)
    error_message = "Log level must be one of: ALL, DEBUG, ERROR, FATAL, INFO, OFF, TRACE, WARN."
  }
}

variable "keycloak_additional_env_vars" {
  description = "Additional environment variables for Keycloak container"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "keycloak_additional_secrets" {
  description = "Additional secrets for Keycloak container (from Secrets Manager)"
  type = list(object({
    name      = string
    valueFrom = string
  }))
  default = []
}

############################################
# Health Check Configuration
############################################

variable "health_check_path" {
  description = "Path for ALB health checks"
  type        = string
  default     = "/health/ready"
}

variable "health_check_interval" {
  description = "Interval in seconds between health checks"
  type        = number
  default     = 30

  validation {
    condition     = var.health_check_interval >= 5 && var.health_check_interval <= 300
    error_message = "Health check interval must be between 5 and 300 seconds."
  }
}

variable "health_check_timeout" {
  description = "Timeout in seconds for health check response"
  type        = number
  default     = 10

  validation {
    condition     = var.health_check_timeout >= 2 && var.health_check_timeout <= 120
    error_message = "Health check timeout must be between 2 and 120 seconds."
  }
}

variable "health_check_healthy_threshold" {
  description = "Number of consecutive successful health checks required"
  type        = number
  default     = 2

  validation {
    condition     = var.health_check_healthy_threshold >= 2 && var.health_check_healthy_threshold <= 10
    error_message = "Healthy threshold must be between 2 and 10."
  }
}

variable "health_check_unhealthy_threshold" {
  description = "Number of consecutive failed health checks required"
  type        = number
  default     = 3

  validation {
    condition     = var.health_check_unhealthy_threshold >= 2 && var.health_check_unhealthy_threshold <= 10
    error_message = "Unhealthy threshold must be between 2 and 10."
  }
}

############################################
# RDS Configuration
############################################

variable "rds_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "16.4"
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20

  validation {
    condition     = var.rds_allocated_storage >= 20 && var.rds_allocated_storage <= 65536
    error_message = "Allocated storage must be between 20 and 65536 GB."
  }
}

variable "rds_max_allocated_storage" {
  description = "Maximum allocated storage for autoscaling (0 to disable)"
  type        = number
  default     = 100
}

variable "rds_database_name" {
  description = "Name of the Keycloak database"
  type        = string
  default     = "keycloak"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.rds_database_name))
    error_message = "Database name must start with a letter and contain only alphanumeric characters and underscores."
  }
}

variable "rds_username" {
  description = "Master username for RDS"
  type        = string
  default     = "keycloak"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.rds_username))
    error_message = "Username must start with a letter and contain only alphanumeric characters and underscores."
  }
}

variable "rds_multi_az" {
  description = "Enable Multi-AZ deployment for RDS"
  type        = bool
  default     = false
}

variable "rds_backup_retention_period" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7

  validation {
    condition     = var.rds_backup_retention_period >= 0 && var.rds_backup_retention_period <= 35
    error_message = "Backup retention period must be between 0 and 35 days."
  }
}

variable "rds_backup_window" {
  description = "Preferred backup window (UTC)"
  type        = string
  default     = "03:00-04:00"
}

variable "rds_maintenance_window" {
  description = "Preferred maintenance window (UTC)"
  type        = string
  default     = "Mon:04:00-Mon:05:00"
}

variable "rds_deletion_protection" {
  description = "Enable deletion protection for RDS"
  type        = bool
  default     = false
}

variable "rds_skip_final_snapshot" {
  description = "Skip final snapshot when deleting RDS instance"
  type        = bool
  default     = true
}

variable "rds_storage_encrypted" {
  description = "Enable storage encryption for RDS"
  type        = bool
  default     = true
}

variable "rds_performance_insights_enabled" {
  description = "Enable Performance Insights for RDS"
  type        = bool
  default     = false
}

variable "rds_performance_insights_retention" {
  description = "Performance Insights retention period in days"
  type        = number
  default     = 7

  validation {
    condition     = contains([7, 31, 62, 93, 124, 155, 186, 217, 248, 279, 310, 341, 372, 403, 434, 465, 496, 527, 558, 589, 620, 651, 682, 713, 731], var.rds_performance_insights_retention)
    error_message = "Performance Insights retention must be 7 days (free tier) or a value between 31 and 731 days."
  }
}

############################################
# CloudWatch Logs Configuration
############################################

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 30

  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch Logs retention period."
  }
}

############################################
# Bastion Host Configuration
############################################

variable "bastion_enabled" {
  description = "Enable bastion host for database access"
  type        = bool
  default     = false
}

variable "bastion_instance_type" {
  description = "EC2 instance type for bastion host"
  type        = string
  default     = "t3.micro"
}

variable "bastion_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to connect to bastion (for SSH/SSM)"
  type        = list(string)
  default     = []
}
