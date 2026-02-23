# Production Keycloak Deployment Example

This example demonstrates a production-ready Keycloak deployment on AWS ECS Fargate with high availability, security, and monitoring features.

## Features

- **High Availability**: 3+ Keycloak tasks across multiple AZs
- **Database HA**: Multi-AZ RDS PostgreSQL with deletion protection
- **Security**: VPC Flow Logs, encrypted storage, bastion host
- **Monitoring**: Performance Insights, Container Insights, extended log retention
- **Scalability**: Auto-scaling from 2 to 10 instances based on CPU/memory
- **Compliance**: ALB access logs for audit trails

## Architecture

```
                    ┌────────────────────────────────────────────────┐
                    │                Production VPC                   │
                    │                                                │
   Internet ──────► │  ALB (Public) ──► ECS Tasks (Public Subnets)  │
                    │                       │                        │
                    │                       ▼                        │
                    │              RDS PostgreSQL (Private Subnets)  │
                    │                   (Multi-AZ)                   │
                    │                                                │
                    │  Bastion ──► (SSM Session Manager)             │
                    └────────────────────────────────────────────────┘
```

## Prerequisites

1. AWS CLI configured with appropriate credentials
2. Terraform >= 1.9.8 installed
3. A Route53 hosted zone for your domain
4. S3 bucket for Terraform state (recommended)

## Usage

### 1. Configure Variables

Create a `terraform.tfvars` file:

```hcl
project_name    = "myapp-prod"
domain_name     = "auth.example.com"
route53_zone_id = "Z1234567890ABC"

# VPC Configuration (optional - defaults are production-ready)
vpc_cidr                 = "10.100.0.0/16"
vpc_public_subnet_cidrs  = ["10.100.1.0/24", "10.100.2.0/24", "10.100.3.0/24"]
vpc_private_subnet_cidrs = ["10.100.10.0/24", "10.100.11.0/24", "10.100.12.0/24"]

# Keycloak Configuration
keycloak_image    = "quay.io/keycloak/keycloak:26.0.6"
keycloak_features = ""

# RDS Configuration
rds_instance_class        = "db.r6g.large"
rds_allocated_storage     = 100
rds_max_allocated_storage = 500

# Bastion Access (your office/VPN CIDR)
bastion_allowed_cidr_blocks = ["203.0.113.0/24"]

tags = {
  Environment = "production"
  Team        = "platform"
  CostCenter  = "infrastructure"
  Compliance  = "soc2"
}
```

### 2. Initialize and Deploy

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan -out=tfplan

# Apply
terraform apply tfplan
```

### 3. Verify Deployment

```bash
# Check ECS service status
aws ecs describe-services \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --services $(terraform output -raw ecs_service_name)

# View Keycloak logs
aws logs tail $(terraform output -raw cloudwatch_log_group_name) --follow

# Verify cluster formation (look for ISPN000094 message)
aws logs filter-log-events \
  --log-group-name $(terraform output -raw cloudwatch_log_group_name) \
  --filter-pattern "ISPN000094"
```

### 4. Get Admin Credentials

```bash
aws secretsmanager get-secret-value \
  --secret-id $(terraform output -raw keycloak_admin_secret_arn) \
  --query 'SecretString' \
  --output text | jq .
```

### 5. Access Admin Console

```bash
open $(terraform output -raw keycloak_url)/admin
```

## Database Access

### Using Session Manager (Recommended)

```bash
# Start SSM session
aws ssm start-session --target $(terraform output -raw bastion_instance_id)

# Once connected, install psql and connect
sudo dnf install -y postgresql16
psql -h <rds-endpoint> -U keycloak -d keycloak
```

### Port Forwarding

```bash
# Forward RDS port through bastion
aws ssm start-session \
  --target $(terraform output -raw bastion_instance_id) \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters '{
    "host":["your-rds-endpoint.rds.amazonaws.com"],
    "portNumber":["5432"],
    "localPortNumber":["5432"]
  }'

# Connect locally
psql -h localhost -U keycloak -d keycloak
```

## Cost Estimate

Approximate monthly costs (us-east-1):

| Component | Configuration | Estimated Cost |
|-----------|---------------|----------------|
| ECS Fargate | 3 x 2 vCPU x 4GB | ~$180 |
| RDS PostgreSQL | db.r6g.large, Multi-AZ, 100GB | ~$300 |
| ALB | 1 ALB + access logs | ~$30 |
| CloudWatch | Logs + Performance Insights | ~$40 |
| Bastion | t3.micro | ~$10 |
| **Total** | | **~$560/month** |

## Security Checklist

- [ ] VPC Flow Logs enabled
- [ ] RDS deletion protection enabled
- [ ] RDS storage encryption enabled
- [ ] Multi-AZ RDS deployment
- [ ] ALB access logs enabled
- [ ] IMDSv2 required on bastion
- [ ] Security groups with least privilege
- [ ] Secrets in AWS Secrets Manager
- [ ] Admin password changed after initial deployment

## Maintenance

### Updating Keycloak

1. Update `keycloak_image` variable
2. Run `terraform apply`
3. ECS performs rolling update automatically

### Database Backups

- Automated daily backups retained for 14 days
- Point-in-time recovery available
- Final snapshot created on deletion

### Scaling

Auto-scaling handles traffic spikes automatically. For planned events:

```bash
# Temporarily increase minimum capacity
aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id service/myapp-prod/myapp-prod-keycloak \
  --scalable-dimension ecs:service:DesiredCount \
  --min-capacity 5
```

## Cleanup

**Warning**: Production cleanup requires careful planning.

1. Disable deletion protection:
   ```hcl
   rds_deletion_protection = false
   ```
2. Apply changes
3. Create manual RDS snapshot
4. Run `terraform destroy`
