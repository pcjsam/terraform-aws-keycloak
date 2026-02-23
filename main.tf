############################################
# Data Sources & Local Variables
############################################

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_elb_service_account" "main" {}

data "aws_ssm_parameter" "bastion_ami" {
  count = var.bastion_enabled ? 1 : 0
  name  = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  availability_zones = length(var.vpc_availability_zones) > 0 ? var.vpc_availability_zones : slice(data.aws_availability_zones.available.names, 0, 2)

  alb_logs_bucket_name = var.alb_access_logs_bucket_name != "" ? var.alb_access_logs_bucket_name : "${var.project_name}-alb-logs-${data.aws_caller_identity.current.account_id}"

  db_url = "jdbc:postgresql://${aws_db_instance.keycloak.endpoint}/${var.rds_database_name}"

  common_tags = merge(var.tags, {
    Project   = var.project_name
    ManagedBy = "terraform"
  })
}

############################################
# SSL Certificate (ACM)
############################################

resource "aws_acm_certificate" "keycloak" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-cert"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  provider = aws.dns

  for_each = {
    for dvo in aws_acm_certificate.keycloak.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = var.dns_record_ttl
  type            = each.value.type
  zone_id         = var.route53_zone_id
}

resource "aws_acm_certificate_validation" "keycloak" {
  certificate_arn         = aws_acm_certificate.keycloak.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

############################################
# VPC & Networking
############################################

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-vpc"
  })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-igw"
  })
}

resource "aws_subnet" "public" {
  count = length(var.vpc_public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.vpc_public_subnet_cidrs[count.index]
  availability_zone       = local.availability_zones[count.index % length(local.availability_zones)]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-${count.index + 1}"
    Type = "public"
  })
}

resource "aws_subnet" "private" {
  count = length(var.vpc_private_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.vpc_private_subnet_cidrs[count.index]
  availability_zone = local.availability_zones[count.index % length(local.availability_zones)]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-private-${count.index + 1}"
    Type = "private"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-private-rt"
  })
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

############################################
# VPC Flow Logs
############################################

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  count = var.vpc_enable_flow_logs ? 1 : 0

  name              = "/aws/vpc/${var.project_name}-flow-logs"
  retention_in_days = var.vpc_flow_logs_retention_days

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-vpc-flow-logs"
  })
}

resource "aws_iam_role" "vpc_flow_logs" {
  count = var.vpc_enable_flow_logs ? 1 : 0

  name = "${var.project_name}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  count = var.vpc_enable_flow_logs ? 1 : 0

  name = "${var.project_name}-vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Effect   = "Allow"
      Resource = "*"
    }]
  })
}

resource "aws_flow_log" "main" {
  count = var.vpc_enable_flow_logs ? 1 : 0

  iam_role_arn    = aws_iam_role.vpc_flow_logs[0].arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs[0].arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-vpc-flow-log"
  })
}

############################################
# Security Groups
############################################

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Security group for Keycloak ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from anywhere (redirects to HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-alb-sg"
  })
}

resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-ecs-tasks-sg"
  description = "Security group for Keycloak ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = var.keycloak_http_port
    to_port         = var.keycloak_http_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "Health check from ALB"
    from_port       = var.keycloak_health_port
    to_port         = var.keycloak_health_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "JGroups cluster communication"
    from_port   = var.keycloak_jgroups_port
    to_port     = var.keycloak_jgroups_port
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "Infinispan replication"
    from_port   = 7900
    to_port     = 7900
    protocol    = "tcp"
    self        = true
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-ecs-tasks-sg"
  })
}

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Security group for Keycloak RDS"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from ECS tasks"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  dynamic "ingress" {
    for_each = var.bastion_enabled ? [1] : []
    content {
      description     = "PostgreSQL from Bastion"
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      security_groups = [aws_security_group.bastion[0].id]
    }
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-rds-sg"
  })
}

resource "aws_security_group" "bastion" {
  count = var.bastion_enabled ? 1 : 0

  name        = "${var.project_name}-bastion-sg"
  description = "Security group for Bastion host"
  vpc_id      = aws_vpc.main.id

  dynamic "ingress" {
    for_each = length(var.bastion_allowed_cidr_blocks) > 0 ? [1] : []
    content {
      description = "SSH from allowed CIDRs"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.bastion_allowed_cidr_blocks
    }
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-bastion-sg"
  })
}

############################################
# S3 Bucket for ALB Access Logs
############################################

resource "aws_s3_bucket" "alb_logs" {
  count = var.alb_access_logs_enabled ? 1 : 0

  bucket = local.alb_logs_bucket_name

  tags = merge(local.common_tags, {
    Name = local.alb_logs_bucket_name
  })
}

resource "aws_s3_bucket_policy" "alb_logs" {
  count = var.alb_access_logs_enabled ? 1 : 0

  bucket = aws_s3_bucket.alb_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = data.aws_elb_service_account.main.arn
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs[0].arn}/*"
      }
    ]
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  count = var.alb_access_logs_enabled ? 1 : 0

  bucket = aws_s3_bucket.alb_logs[0].id

  rule {
    id     = "expire-logs"
    status = "Enabled"

    expiration {
      days = 90
    }
  }
}

############################################
# Application Load Balancer
############################################

resource "aws_lb" "keycloak" {
  name               = "${var.project_name}-alb"
  internal           = var.alb_internal
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
  idle_timeout       = var.alb_idle_timeout

  dynamic "access_logs" {
    for_each = var.alb_access_logs_enabled ? [1] : []
    content {
      bucket  = aws_s3_bucket.alb_logs[0].id
      prefix  = "keycloak"
      enabled = true
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-alb"
  })
}

resource "aws_lb_target_group" "keycloak" {
  name        = "${var.project_name}-tg"
  port        = var.keycloak_http_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = var.health_check_path
    port                = var.keycloak_health_port
    protocol            = "HTTP"
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
    timeout             = var.health_check_timeout
    interval            = var.health_check_interval
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-tg"
  })
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.keycloak.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = var.alb_ssl_policy
  certificate_arn   = aws_acm_certificate_validation.keycloak.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.keycloak.arn
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-https-listener"
  })
}

resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.keycloak.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-http-redirect-listener"
  })
}

############################################
# DNS Record
############################################

resource "aws_route53_record" "keycloak" {
  provider = aws.dns

  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.keycloak.dns_name
    zone_id                = aws_lb.keycloak.zone_id
    evaluate_target_health = true
  }
}

############################################
# ECS Cluster
############################################

resource "aws_ecs_cluster" "keycloak" {
  name = var.project_name

  setting {
    name  = "containerInsights"
    value = var.ecs_container_insights_enabled ? "enhanced" : "disabled"
  }

  tags = merge(local.common_tags, {
    Name = var.project_name
  })
}

resource "aws_ecs_cluster_capacity_providers" "keycloak" {
  cluster_name = aws_ecs_cluster.keycloak.name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

############################################
# CloudWatch Log Group for ECS
############################################

resource "aws_cloudwatch_log_group" "keycloak" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-logs"
  })
}

############################################
# Secrets Manager - Keycloak Admin Credentials
############################################

resource "random_password" "keycloak_admin" {
  count = var.keycloak_admin_password == "" ? 1 : 0

  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "keycloak_admin" {
  name = "${var.project_name}/admin"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-admin-secret"
  })
}

resource "aws_secretsmanager_secret_version" "keycloak_admin" {
  secret_id = aws_secretsmanager_secret.keycloak_admin.id
  secret_string = jsonencode({
    username = var.keycloak_admin_username
    password = var.keycloak_admin_password != "" ? var.keycloak_admin_password : random_password.keycloak_admin[0].result
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

############################################
# ECS Task Execution Role
############################################

resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.project_name}-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  name = "${var.project_name}-secrets-policy"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.keycloak_admin.arn,
          aws_db_instance.keycloak.master_user_secret[0].secret_arn
        ]
      }
    ]
  })
}

data "aws_iam_policy_document" "cross_account_ecr_pull" {
  count = var.keycloak_cross_account_ecr_repository_arn != "" ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage"
    ]
    resources = [var.keycloak_cross_account_ecr_repository_arn]
  }
}

resource "aws_iam_policy" "cross_account_ecr_pull" {
  count = var.keycloak_cross_account_ecr_repository_arn != "" ? 1 : 0

  name        = "${var.project_name}-cross-account-ecr-policy"
  description = "Allows Keycloak ECS task execution role to pull images from cross-account ECR repository"
  policy      = data.aws_iam_policy_document.cross_account_ecr_pull[0].json

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-cross-account-ecr-policy"
  })
}

resource "aws_iam_role_policy_attachment" "cross_account_ecr_pull" {
  count = var.keycloak_cross_account_ecr_repository_arn != "" ? 1 : 0

  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = aws_iam_policy.cross_account_ecr_pull[0].arn
}

############################################
# ECS Task Role
############################################

resource "aws_iam_role" "ecs_task" {
  name = "${var.project_name}-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = local.common_tags
}

############################################
# ECS Task Definition
############################################

resource "aws_ecs_task_definition" "keycloak" {
  family                   = var.project_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.keycloak_task_cpu
  memory                   = var.keycloak_task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "keycloak"
      image     = var.keycloak_image
      essential = true
      command   = ["start", "--optimized"]

      portMappings = [
        {
          containerPort = var.keycloak_http_port
          protocol      = "tcp"
        },
        {
          containerPort = var.keycloak_health_port
          protocol      = "tcp"
        },
        {
          containerPort = var.keycloak_jgroups_port
          protocol      = "tcp"
        }
      ]

      environment = concat([
        {
          name  = "KC_DB_URL"
          value = local.db_url
        },
        {
          name  = "KC_HOSTNAME"
          value = var.domain_name
        },
        {
          name  = "KC_HOSTNAME_STRICT"
          value = tostring(var.keycloak_hostname_strict)
        },
        {
          name  = "KC_PROXY_HEADERS"
          value = "xforwarded"
        },
        {
          name  = "KC_HTTP_ENABLED"
          value = "true"
        },
        {
          name  = "KC_HTTP_MANAGEMENT_PORT"
          value = tostring(var.keycloak_health_port)
        },
        {
          name  = "KC_LOG_LEVEL"
          value = var.keycloak_log_level
        },
        {
          name  = "JAVA_OPTS_APPEND"
          value = "-Djgroups.dns.query=${var.project_name}.${var.project_name}.local -Djgroups.bind.address=SITE_LOCAL"
        }
      ], var.keycloak_additional_env_vars)

      secrets = concat([
        {
          name      = "KEYCLOAK_ADMIN"
          valueFrom = "${aws_secretsmanager_secret.keycloak_admin.arn}:username::"
        },
        {
          name      = "KEYCLOAK_ADMIN_PASSWORD"
          valueFrom = "${aws_secretsmanager_secret.keycloak_admin.arn}:password::"
        },
        {
          name      = "KC_DB_USERNAME"
          valueFrom = "${aws_db_instance.keycloak.master_user_secret[0].secret_arn}:username::"
        },
        {
          name      = "KC_DB_PASSWORD"
          valueFrom = "${aws_db_instance.keycloak.master_user_secret[0].secret_arn}:password::"
        }
      ], var.keycloak_additional_secrets)

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.keycloak.name
          "awslogs-region"        = data.aws_region.current.id
          "awslogs-stream-prefix" = "keycloak"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.keycloak_health_port}/health/ready || exit 1"]
        interval    = var.health_check_interval
        timeout     = var.health_check_timeout
        retries     = var.health_check_unhealthy_threshold
        startPeriod = var.health_check_start_period
      }
    }
  ])

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-task"
  })
}

############################################
# ECS Service Discovery (for clustering)
############################################

resource "aws_service_discovery_private_dns_namespace" "keycloak" {
  name        = "${var.project_name}.local"
  description = "Service discovery namespace for Keycloak clustering"
  vpc         = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-service-discovery"
  })
}

resource "aws_service_discovery_service" "keycloak" {
  name = var.project_name

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.keycloak.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
  }

  force_destroy = true

  tags = local.common_tags
}

############################################
# ECS Service
############################################

resource "aws_ecs_service" "keycloak" {
  name            = var.project_name
  cluster         = aws_ecs_cluster.keycloak.id
  task_definition = aws_ecs_task_definition.keycloak.arn
  desired_count   = var.keycloak_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.keycloak.arn
    container_name   = "keycloak"
    container_port   = var.keycloak_http_port
  }

  service_registries {
    registry_arn = aws_service_discovery_service.keycloak.arn
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  depends_on = [
    aws_lb_listener.https,
    aws_db_instance.keycloak
  ]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-service"
  })
}

############################################
# ECS Auto Scaling
############################################

resource "aws_appautoscaling_target" "keycloak" {
  max_capacity       = var.keycloak_max_capacity
  min_capacity       = var.keycloak_min_capacity
  resource_id        = "service/${aws_ecs_cluster.keycloak.name}/${aws_ecs_service.keycloak.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  tags = local.common_tags
}

resource "aws_appautoscaling_policy" "keycloak_cpu" {
  name               = "${var.project_name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.keycloak.resource_id
  scalable_dimension = aws_appautoscaling_target.keycloak.scalable_dimension
  service_namespace  = aws_appautoscaling_target.keycloak.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.keycloak_autoscaling_cpu_target
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

resource "aws_appautoscaling_policy" "keycloak_memory" {
  name               = "${var.project_name}-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.keycloak.resource_id
  scalable_dimension = aws_appautoscaling_target.keycloak.scalable_dimension
  service_namespace  = aws_appautoscaling_target.keycloak.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = var.keycloak_autoscaling_memory_target
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

############################################
# RDS PostgreSQL Database
############################################

resource "aws_db_subnet_group" "keycloak" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-db-subnet-group"
  })
}

resource "aws_db_instance" "keycloak" {
  identifier = "${var.project_name}-db"

  # Engine configuration
  engine                = "postgres"
  engine_version        = var.rds_engine_version
  instance_class        = var.rds_instance_class
  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = var.rds_max_allocated_storage > 0 ? var.rds_max_allocated_storage : null
  storage_type          = "gp3"
  storage_encrypted     = var.rds_storage_encrypted

  # Database configuration
  db_name  = var.rds_database_name
  username = var.rds_username
  # Password managed by AWS Secrets Manager
  manage_master_user_password = true

  # Network configuration
  db_subnet_group_name   = aws_db_subnet_group.keycloak.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  port                   = 5432

  # High availability
  multi_az = var.rds_multi_az

  # Backup configuration
  backup_retention_period = var.rds_backup_retention_period
  backup_window           = var.rds_backup_window
  maintenance_window      = var.rds_maintenance_window

  # Performance Insights
  performance_insights_enabled          = var.rds_performance_insights_enabled
  performance_insights_retention_period = var.rds_performance_insights_enabled ? var.rds_performance_insights_retention : null

  # Protection
  deletion_protection       = var.rds_deletion_protection
  skip_final_snapshot       = var.rds_skip_final_snapshot
  final_snapshot_identifier = var.rds_skip_final_snapshot ? null : "${var.project_name}-db-final-snapshot"

  # Enable IAM authentication
  iam_database_authentication_enabled = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-db"
  })
}

############################################
# Bastion Host - Secure Database Access
############################################

resource "aws_iam_role" "bastion" {
  count = var.bastion_enabled ? 1 : 0

  name = "${var.project_name}-bastion-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  count = var.bastion_enabled ? 1 : 0

  role       = aws_iam_role.bastion[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bastion" {
  count = var.bastion_enabled ? 1 : 0

  name = "${var.project_name}-bastion-profile"
  role = aws_iam_role.bastion[0].name

  tags = local.common_tags
}

resource "aws_instance" "bastion" {
  count = var.bastion_enabled ? 1 : 0

  ami                    = data.aws_ssm_parameter.bastion_ami[0].value
  instance_type          = var.bastion_instance_type
  subnet_id              = aws_subnet.private[0].id
  vpc_security_group_ids = [aws_security_group.bastion[0].id]
  iam_instance_profile   = aws_iam_instance_profile.bastion[0].name

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
  }

  user_data = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y postgresql16
  EOF

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-bastion"
  })
}
