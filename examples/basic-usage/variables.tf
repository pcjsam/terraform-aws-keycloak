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
# Keycloak Configuration
############################################

variable "keycloak_image" {
  description = "Docker image for Keycloak (should be your custom-built production image)"
  type        = string
}

############################################
# Optional Variables
############################################

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "development"
    ManagedBy   = "terraform"
  }
}
