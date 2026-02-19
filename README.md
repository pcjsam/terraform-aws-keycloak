# Terraform AWS Keycloak

This Terraform module deploys a production-ready Keycloak instance on AWS using ECS Fargate with PostgreSQL RDS.

## Features

- **ECS Fargate**: Serverless container orchestration - no EC2 instances to manage
- **High Availability**: Multi-AZ deployment with auto-scaling (2-10 instances by default)
- **Clustering**: Automatic Keycloak cluster formation using DNS-based service discovery
- **Managed Database**: RDS PostgreSQL with automated backups and optional Multi-AZ
- **Secure by Default**: Private subnets, security group isolation, encrypted storage
- **HTTPS Only**: ACM certificate with automatic DNS validation and HTTP-to-HTTPS redirect
- **Secrets Management**: AWS Secrets Manager for admin and database credentials
- **Observability**: CloudWatch logs, Container Insights, optional VPC Flow Logs
- **Auto-Scaling**: CPU and memory-based scaling policies
- **Optional Bastion**: SSM-enabled bastion host for database access

## Architecture Overview

```
                                    ┌─────────────────────────────────────────────────────┐
                                    │                        VPC                          │
                                    │  ┌─────────────────────────────────────────────┐   │
       ┌──────────┐                 │  │              Public Subnets                 │   │
       │  Users   │                 │  │  ┌─────────────────────────────────────┐   │   │
       └────┬─────┘                 │  │  │     Application Load Balancer       │   │   │
            │                       │  │  │         (HTTPS: 443)                 │   │   │
            │ HTTPS                 │  │  └──────────────────┬──────────────────┘   │   │
            ▼                       │  │                     │                       │   │
    ┌───────────────┐               │  └─────────────────────┼───────────────────────┘   │
    │   Route53     │               │                        │                           │
    │  (DNS A Record)│──────────────┼────────────────────────┘                           │
    └───────────────┘               │  ┌─────────────────────────────────────────────┐   │
                                    │  │              Private Subnets                │   │
                                    │  │                                             │   │
                                    │  │   ┌─────────────┐     ┌─────────────┐      │   │
                                    │  │   │  Keycloak   │     │  Keycloak   │      │   │
                                    │  │   │  (Fargate)  │◄───►│  (Fargate)  │      │   │
                                    │  │   │   Task 1    │     │   Task 2    │      │   │
                                    │  │   └──────┬──────┘     └──────┬──────┘      │   │
                                    │  │          │                   │              │   │
                                    │  │          │    ┌──────────────┘              │   │
                                    │  │          │    │                             │   │
                                    │  │          ▼    ▼                             │   │
                                    │  │   ┌─────────────────┐                       │   │
                                    │  │   │  RDS PostgreSQL │                       │   │
                                    │  │   │   (Multi-AZ)    │                       │   │
                                    │  │   └─────────────────┘                       │   │
                                    │  │                                             │   │
                                    │  └─────────────────────────────────────────────┘   │
                                    │                                                     │
                                    │  ┌─────────────────────────────────────────────┐   │
                                    │  │                NAT Gateway                   │   │
                                    │  │         (Outbound Internet Access)           │   │
                                    │  └─────────────────────────────────────────────┘   │
                                    │                                                     │
                                    └─────────────────────────────────────────────────────┘
```

## Prerequisites

Before using this module, ensure you have:

1. **Terraform >= 1.9.8** installed
2. **AWS CLI** configured with appropriate credentials
3. **AWS Account** with permissions to create:
   - VPC, Subnets, Security Groups, NAT Gateway
   - ECS Cluster, Services, Task Definitions
   - RDS PostgreSQL instances
   - Application Load Balancer
   - ACM Certificates
   - Route53 records
   - IAM Roles and Policies
   - Secrets Manager secrets
   - CloudWatch Log Groups

4. **Route53 Hosted Zone** for your domain (for DNS validation and record creation)

## Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `project_name` | Name prefix for all resources | `"myapp"` |
| `domain_name` | Domain name for Keycloak | `"auth.example.com"` |
| `route53_zone_id` | Route53 hosted zone ID | `"Z1234567890ABC"` |

## Optional Variables

### General Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `tags` | Tags to apply to all resources | `{}` |

### VPC Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `vpc_cidr` | CIDR block for the VPC | `"10.0.0.0/16"` |
| `vpc_public_subnet_cidrs` | CIDR blocks for public subnets | `["10.0.1.0/24", "10.0.2.0/24"]` |
| `vpc_private_subnet_cidrs` | CIDR blocks for private subnets | `["10.0.10.0/24", "10.0.11.0/24"]` |
| `vpc_availability_zones` | Availability zones (auto-detected if empty) | `[]` |
| `vpc_enable_flow_logs` | Enable VPC flow logs | `false` |
| `vpc_flow_logs_retention_days` | Flow logs retention period | `14` |

### ALB Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `alb_internal` | Whether ALB is internal | `false` |
| `alb_idle_timeout` | Connection idle timeout (seconds) | `60` |
| `alb_access_logs_enabled` | Enable ALB access logs | `false` |
| `alb_ssl_policy` | SSL policy for HTTPS listener | `"ELBSecurityPolicy-TLS13-1-2-2021-06"` |

### Keycloak Task Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `keycloak_image` | Docker image for Keycloak | `"quay.io/keycloak/keycloak:26.0.6"` |
| `keycloak_cross_account_ecr_repository_arn` | ECR repository ARN from another account (for cross-account pulls) | `""` |
| `keycloak_task_cpu` | CPU units (1024 = 1 vCPU) | `1024` |
| `keycloak_task_memory` | Memory in MB | `2048` |
| `keycloak_desired_count` | Desired number of tasks | `2` |
| `keycloak_min_capacity` | Minimum tasks for auto-scaling | `2` |
| `keycloak_max_capacity` | Maximum tasks for auto-scaling | `10` |
| `keycloak_autoscaling_cpu_target` | CPU target for auto-scaling (%) | `70` |
| `keycloak_autoscaling_memory_target` | Memory target for auto-scaling (%) | `80` |

### Keycloak Application Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `keycloak_admin_username` | Admin username | `"admin"` |
| `keycloak_admin_password` | Admin password (auto-generated if empty) | `""` |
| `keycloak_hostname_strict` | Enable strict hostname checking | `true` |
| `keycloak_features` | Features to enable (comma-separated) | `""` |
| `keycloak_features_disabled` | Features to disable (comma-separated) | `""` |
| `keycloak_log_level` | Log level | `"INFO"` |
| `keycloak_metrics_enabled` | Enable metrics endpoint | `true` |
| `keycloak_health_enabled` | Enable health endpoints | `true` |
| `keycloak_additional_env_vars` | Additional environment variables | `[]` |
| `keycloak_additional_secrets` | Additional secrets from Secrets Manager | `[]` |

### RDS Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `rds_engine_version` | PostgreSQL engine version | `"16.4"` |
| `rds_instance_class` | RDS instance class | `"db.t3.micro"` |
| `rds_allocated_storage` | Allocated storage in GB | `20` |
| `rds_max_allocated_storage` | Max storage for autoscaling (0 to disable) | `100` |
| `rds_database_name` | Database name | `"keycloak"` |
| `rds_username` | Master username | `"keycloak"` |
| `rds_multi_az` | Enable Multi-AZ deployment | `false` |
| `rds_backup_retention_period` | Backup retention in days | `7` |
| `rds_deletion_protection` | Enable deletion protection | `false` |
| `rds_storage_encrypted` | Enable storage encryption | `true` |
| `rds_performance_insights_enabled` | Enable Performance Insights | `false` |

### Bastion Host Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `bastion_enabled` | Enable bastion host | `false` |
| `bastion_instance_type` | EC2 instance type | `"t3.micro"` |
| `bastion_allowed_cidr_blocks` | CIDRs allowed to connect | `[]` |

## Outputs

| Output | Description |
|--------|-------------|
| `keycloak_url` | URL for Keycloak |
| `keycloak_admin_console_url` | URL for Keycloak admin console |
| `alb_dns_name` | DNS name of the ALB |
| `vpc_id` | ID of the VPC |
| `ecs_cluster_name` | Name of the ECS cluster |
| `ecs_service_name` | Name of the ECS service |
| `rds_endpoint` | RDS instance endpoint |
| `keycloak_admin_secret_arn` | ARN of Keycloak admin credentials secret |
| `rds_master_user_secret_arn` | ARN of RDS master credentials secret |

## Usage

### Basic Example

```hcl
module "keycloak" {
  source = "path/to/terraform-aws-keycloak"

  project_name    = "myapp"
  domain_name     = "auth.example.com"
  route53_zone_id = "Z1234567890ABC"

  tags = {
    Environment = "production"
    Team        = "platform"
  }
}

output "keycloak_url" {
  value = module.keycloak.keycloak_url
}
```

### Production Example

```hcl
module "keycloak" {
  source = "path/to/terraform-aws-keycloak"

  project_name    = "myapp"
  domain_name     = "auth.example.com"
  route53_zone_id = "Z1234567890ABC"

  # VPC Configuration
  vpc_cidr                 = "10.100.0.0/16"
  vpc_public_subnet_cidrs  = ["10.100.1.0/24", "10.100.2.0/24", "10.100.3.0/24"]
  vpc_private_subnet_cidrs = ["10.100.10.0/24", "10.100.11.0/24", "10.100.12.0/24"]
  vpc_enable_flow_logs     = true

  # ALB Configuration
  alb_access_logs_enabled = true

  # Keycloak Configuration
  keycloak_image        = "quay.io/keycloak/keycloak:26.0.6"
  keycloak_task_cpu     = 2048
  keycloak_task_memory  = 4096
  keycloak_desired_count = 3
  keycloak_min_capacity  = 2
  keycloak_max_capacity  = 10
  keycloak_log_level     = "INFO"

  # RDS Configuration (Production)
  rds_instance_class               = "db.r6g.large"
  rds_allocated_storage            = 100
  rds_multi_az                     = true
  rds_backup_retention_period      = 14
  rds_deletion_protection          = true
  rds_skip_final_snapshot          = false
  rds_performance_insights_enabled = true

  # Logging
  log_retention_days = 90

  # Enable bastion for database access
  bastion_enabled = true

  tags = {
    Environment = "production"
    Team        = "platform"
    CostCenter  = "infrastructure"
  }
}
```

### Custom Keycloak Image Example

For production deployments, you may want to use a custom Keycloak image with pre-built optimizations:

```hcl
module "keycloak" {
  source = "path/to/terraform-aws-keycloak"

  project_name    = "myapp"
  domain_name     = "auth.example.com"
  route53_zone_id = "Z1234567890ABC"

  # Use custom image from same-account ECR
  keycloak_image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/keycloak:26.0.6-custom"

  # Enable specific features
  keycloak_features          = "preview,token-exchange"
  keycloak_features_disabled = "impersonation"

  # Additional environment variables
  keycloak_additional_env_vars = [
    {
      name  = "KC_SPI_THEME_DEFAULT"
      value = "custom-theme"
    }
  ]

  tags = {
    Environment = "production"
  }
}
```

### Cross-Account ECR Example

When your Keycloak image is stored in a shared services account's ECR repository:

```hcl
module "keycloak" {
  source = "path/to/terraform-aws-keycloak"

  project_name    = "myapp"
  domain_name     = "auth.example.com"
  route53_zone_id = "Z1234567890ABC"

  # Image from cross-account ECR (shared services account)
  keycloak_image = "111111111111.dkr.ecr.us-east-1.amazonaws.com/keycloak:26.0.6"

  # Provide the ECR repository ARN to grant pull permissions
  keycloak_cross_account_ecr_repository_arn = "arn:aws:ecr:us-east-1:111111111111:repository/keycloak"

  tags = {
    Environment = "production"
  }
}
```

**Note**: The source ECR repository must have a resource policy allowing the target account to pull images:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCrossAccountPull",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::222222222222:root"
      },
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer"
      ]
    }
  ]
}
```

## Updating Keycloak

This module uses Terraform-managed rolling updates. To update Keycloak:

### 1. Update the Image Variable

```hcl
# Change the image tag
keycloak_image = "111111111111.dkr.ecr.us-east-1.amazonaws.com/keycloak:26.1.0"
```

### 2. Apply the Change

```bash
terraform plan   # Review the changes
terraform apply  # Apply the update
```

### 3. Monitor the Deployment

ECS performs a rolling update:
1. New tasks are launched with the new image
2. ALB health checks verify new tasks are healthy
3. Traffic shifts to new tasks
4. Old tasks are drained and stopped

```bash
# Watch the deployment
aws ecs describe-services \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --services $(terraform output -raw ecs_service_name) \
  --query 'services[0].deployments'
```

### Automatic Rollback

The module configures deployment circuit breaker with automatic rollback. If new tasks fail health checks, ECS automatically rolls back to the previous version.

## Post-Deployment Steps

### 1. Wait for Certificate Provisioning

ACM certificates require DNS validation. The module creates the validation records automatically, but certificate provisioning can take up to 30 minutes.

```bash
# Check certificate status
aws acm describe-certificate \
  --certificate-arn $(terraform output -raw acm_certificate_arn) \
  --query 'Certificate.Status'
```

### 2. Verify ECS Service Health

```bash
# Check ECS service status
aws ecs describe-services \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --services $(terraform output -raw ecs_service_name) \
  --query 'services[0].{status:status,runningCount:runningCount,desiredCount:desiredCount}'
```

### 3. Access Keycloak Admin Console

```bash
# Get the admin credentials
aws secretsmanager get-secret-value \
  --secret-id $(terraform output -raw keycloak_admin_secret_arn) \
  --query 'SecretString' \
  --output text | jq .
```

Then navigate to `https://auth.example.com/admin` and log in with the credentials.

### 4. Verify Cluster Formation

Check the Keycloak logs to verify that instances have formed a cluster:

```bash
# View recent logs
aws logs tail /ecs/myapp/keycloak --since 5m --follow
```

Look for messages like:
```
INFO [org.infinispan.CLUSTER] ISPN000094: Received new cluster view: [node1|1] (2) [node1, node2]
```

## Database Access

### Using Session Manager (Recommended)

If you enabled the bastion host, you can use AWS Session Manager to access the database:

```bash
# Start a session
aws ssm start-session \
  --target $(terraform output -raw bastion_instance_id)

# Once connected, use psql
psql -h $(terraform output -raw rds_address) \
     -U keycloak \
     -d keycloak
```

### Using Session Manager Port Forwarding

```bash
# Start port forwarding
aws ssm start-session \
  --target $(terraform output -raw bastion_instance_id) \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters '{
    "host":["your-rds-endpoint.rds.amazonaws.com"],
    "portNumber":["5432"],
    "localPortNumber":["5432"]
  }'

# In another terminal, connect locally
psql -h localhost -U keycloak -d keycloak
```

## Realm Configuration with Terraform

Use the [Terraform Keycloak Provider](https://registry.terraform.io/providers/mrparkers/keycloak/latest) to manage realms, clients, and users as code:

```hcl
provider "keycloak" {
  client_id = "admin-cli"
  username  = jsondecode(data.aws_secretsmanager_secret_version.keycloak_admin.secret_string)["username"]
  password  = jsondecode(data.aws_secretsmanager_secret_version.keycloak_admin.secret_string)["password"]
  url       = module.keycloak.keycloak_url
}

resource "keycloak_realm" "app" {
  realm   = "my-application"
  enabled = true
}

resource "keycloak_openid_client" "frontend" {
  realm_id              = keycloak_realm.app.id
  client_id             = "frontend-app"
  access_type           = "PUBLIC"
  standard_flow_enabled = true
  valid_redirect_uris   = ["https://app.example.com/*"]
}
```

## Keycloak Clustering

This module configures Keycloak clustering using DNS-based service discovery:

1. **Service Discovery**: AWS Cloud Map creates DNS records for each Keycloak task
2. **JGroups DNS_PING**: Keycloak uses DNS queries to discover other cluster members
3. **Infinispan**: Distributed cache replicates sessions across all nodes

This approach is simpler than JDBC_PING and doesn't require additional database load.

## Cost Estimate

Approximate monthly costs (us-east-1, as of 2024):

| Component | Configuration | Estimated Cost |
|-----------|---------------|----------------|
| ECS Fargate | 2 tasks × 1 vCPU × 2GB | ~$60 |
| RDS PostgreSQL | db.t3.micro, 20GB | ~$15 |
| NAT Gateway | 1 gateway + data transfer | ~$35 |
| ALB | 1 ALB + LCU charges | ~$20 |
| Route53 | Hosted zone + queries | ~$1 |
| CloudWatch | Logs + Container Insights | ~$10 |
| **Total** | | **~$140/month** |

For production with Multi-AZ RDS and larger instances, expect $300-500/month.

## Security Considerations

### Implemented Security Features

- **Network Isolation**: ECS tasks and RDS run in private subnets
- **Security Groups**: Strict ingress rules (ALB → ECS → RDS)
- **Encryption**: RDS storage encryption, HTTPS only
- **Secrets Management**: Credentials stored in AWS Secrets Manager
- **IMDSv2**: Bastion host requires IMDSv2
- **No Public IPs**: ECS tasks have no public IP addresses

### Recommendations

1. **Enable VPC Flow Logs** for network monitoring
2. **Enable RDS deletion protection** for production
3. **Use Multi-AZ RDS** for production high availability
4. **Rotate admin credentials** regularly
5. **Enable RDS Performance Insights** for production monitoring
6. **Consider AWS WAF** for additional protection

## Troubleshooting

### ECS Tasks Not Starting

1. Check CloudWatch logs:
   ```bash
   aws logs tail /ecs/myapp/keycloak --since 30m
   ```

2. Check task stopped reason:
   ```bash
   aws ecs describe-tasks \
     --cluster myapp \
     --tasks $(aws ecs list-tasks --cluster myapp --query 'taskArns[0]' --output text)
   ```

### Database Connection Issues

1. Verify security groups allow traffic
2. Check RDS endpoint is correct in task definition
3. Verify Secrets Manager permissions

### Certificate Not Provisioning

1. Verify DNS validation records exist:
   ```bash
   aws acm describe-certificate --certificate-arn <arn> --query 'Certificate.DomainValidationOptions'
   ```

2. Check Route53 record propagation:
   ```bash
   dig _validation-record.auth.example.com CNAME
   ```

### Cluster Not Forming

1. Verify service discovery is working:
   ```bash
   aws servicediscovery list-instances --service-id <service-id>
   ```

2. Check JGroups port (7800) is open between tasks
3. Verify DNS resolution from within tasks

## Maintenance

### Updating Keycloak Version

1. Update the `keycloak_image` variable
2. Run `terraform apply`
3. ECS will perform a rolling update

### Scaling

Adjust `keycloak_min_capacity` and `keycloak_max_capacity` for manual scaling bounds, or let auto-scaling handle it based on CPU/memory utilization.

### Database Maintenance

RDS maintenance windows are configurable via `rds_maintenance_window`. During maintenance, there may be brief interruptions for single-AZ deployments.

## Contributing

Contributions are welcome! Please submit pull requests with:

1. Clear description of changes
2. Updated documentation
3. Tested configurations

## License

MIT License - see LICENSE file for details.

## Support

For issues and questions:

- Review the Troubleshooting section above
- Check [Keycloak documentation](https://www.keycloak.org/documentation)
- Check [AWS ECS documentation](https://docs.aws.amazon.com/ecs/)
- Open an issue in this repository
