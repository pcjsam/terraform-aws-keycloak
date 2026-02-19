# Basic Keycloak Deployment Example

This example demonstrates a minimal Keycloak deployment on AWS ECS Fargate suitable for development and testing environments.

## Features

- Minimal resource allocation (1 vCPU, 2GB RAM per task)
- 2 Keycloak tasks for basic high availability
- Single-AZ RDS PostgreSQL (no Multi-AZ)
- Auto-generated admin password stored in Secrets Manager
- 7-day log retention
- No bastion host

## Prerequisites

1. AWS CLI configured with appropriate credentials
2. Terraform >= 1.9.8 installed
3. A Route53 hosted zone for your domain

## Usage

1. Create a `terraform.tfvars` file:

```hcl
project_name    = "myapp-dev"
domain_name     = "auth-dev.example.com"
route53_zone_id = "Z1234567890ABC"

tags = {
  Environment = "development"
  Team        = "platform"
}
```

2. Initialize and apply:

```bash
terraform init
terraform plan
terraform apply
```

3. Wait for deployment to complete (5-10 minutes)

4. Get admin credentials:

```bash
aws secretsmanager get-secret-value \
  --secret-id $(terraform output -raw keycloak_admin_secret_arn) \
  --query 'SecretString' \
  --output text | jq .
```

5. Access Keycloak:

```bash
open $(terraform output -raw keycloak_admin_console_url)
```

## Cost Estimate

Approximate monthly cost: ~$100-120

| Component | Configuration | Estimated Cost |
|-----------|---------------|----------------|
| ECS Fargate | 2 × 1 vCPU × 2GB | ~$60 |
| RDS PostgreSQL | db.t3.micro, 20GB | ~$15 |
| NAT Gateway | 1 gateway | ~$35 |
| ALB | 1 ALB | ~$20 |

## Cleanup

```bash
terraform destroy
```

## Next Steps

For production deployments, see the [production-usage](../production-usage) example.
