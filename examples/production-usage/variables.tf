############################################
# Required Variables
############################################

variable "project_name" {
  description = "Name of the project, used as prefix for all resources"
  type        = string
}

variable "domain_name" {
  description = "Domain name for Keycloak (e.g., auth.example.com)"
  type        = string
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for DNS validation and record creation"
  type        = string
}

############################################
# VPC Configuration
############################################

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.100.0.0/16"
}

variable "vpc_public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (3 AZs for production)"
  type        = list(string)
  default     = ["10.100.1.0/24", "10.100.2.0/24", "10.100.3.0/24"]
}

variable "vpc_private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (3 AZs for production)"
  type        = list(string)
  default     = ["10.100.10.0/24", "10.100.11.0/24", "10.100.12.0/24"]
}

############################################
# Keycloak Configuration
############################################

variable "keycloak_image" {
  description = "Docker image for Keycloak (e.g., 123456789.dkr.ecr.us-east-1.amazonaws.com/keycloak:26.0.6)"
  type        = string
  default     = "quay.io/keycloak/keycloak:26.0.6"
}

variable "keycloak_cross_account_ecr_repository_arn" {
  description = "ECR repository ARN if using cross-account ECR. Leave empty for same-account ECR or public registry."
  type        = string
  default     = ""
}

variable "keycloak_features" {
  description = "Keycloak features to enable (comma-separated)"
  type        = string
  default     = ""
}

############################################
# RDS Configuration
############################################

variable "rds_instance_class" {
  description = "RDS instance class for production"
  type        = string
  default     = "db.r6g.large"
}

variable "rds_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 100
}

variable "rds_max_allocated_storage" {
  description = "Maximum allocated storage for autoscaling"
  type        = number
  default     = 500
}

############################################
# Bastion Configuration
############################################

variable "bastion_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to connect to bastion (your office IP, VPN, etc.)"
  type        = list(string)
  default     = []
}

############################################
# Tags
############################################

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
