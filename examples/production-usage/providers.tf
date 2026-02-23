############################################
# Terraform and Provider Configuration
############################################

terraform {
  required_version = "~> 1.9.8"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.82.0"
    }

    # Uncomment to enable Keycloak realm management
    # keycloak = {
    #   source  = "mrparkers/keycloak"
    #   version = "~> 4.4.0"
    # }
  }

  # Configure remote state for production
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "keycloak/prod/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
}

############################################
# Primary AWS Provider
# This is where all infrastructure will be deployed
############################################

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = "production"
      ManagedBy   = "terraform"
    }
  }
}

############################################
# DNS Provider (Cross-Account)
# Configure this to manage Route53 records in a different account
############################################

# Option 1: Same account (DNS zone in same account as infrastructure)
# provider "aws" {
#   alias  = "dns"
#   region = "us-east-1"
# }

# Option 2: Cross-account (DNS zone in a central/shared account)
provider "aws" {
  alias  = "dns"
  region = "us-east-1"

  # Assume a role in the DNS account to manage Route53 records
  assume_role {
    role_arn     = var.dns_account_role_arn
    session_name = "keycloak-terraform"
  }

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = "production"
      ManagedBy   = "terraform"
    }
  }
}
