# terraform/ecs.tf
# ECS Cluster, Task Definitions, and Services

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = { Name = "${local.name_prefix}-cluster" }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "services" {
  for_each          = local.services
  name              = "/ecs/${local.name_prefix}/${each.key}"
  retention_in_days = 14
  tags              = { Name = "${local.name_prefix}-${each.key}-logs" }
}

# Task Definitions
resource "aws_ecs_task_definition" "frontend" {
  family                   = "${local.name_prefix}-frontend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = local.services["frontend"].cpu
  memory                   = local.services["frontend"].memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "frontend"
      image = "${aws_ecr_repository.services["frontend"].repository_url}:${var.frontend_image_tag}"

      portMappings = [{
        containerPort = 80
        protocol      = "tcp"
      }]

      environment = [
        { name = "API_URL", value = "" } # Handled by nginx proxy
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.services["frontend"].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = { Name = "${local.name_prefix}-frontend-task" }
}

resource "aws_ecs_task_definition" "inspection_api" {
  family                   = "${local.name_prefix}-inspection-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = local.services["inspection-api"].cpu
  memory                   = local.services["inspection-api"].memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "inspection-api"
      image = "${aws_ecr_repository.services["inspection-api"].repository_url}:${var.inspection_api_image_tag}"

      portMappings = [{
        containerPort = 3001
        protocol      = "tcp"
      }]

      environment = concat(local.backend_env_vars, [
        { name = "PORT", value = "3001" },
        { name = "NODE_ENV", value = var.environment }
      ])

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.services["inspection-api"].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:3001/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = { Name = "${local.name_prefix}-inspection-api-task" }
}

resource "aws_ecs_task_definition" "report_service" {
  family                   = "${local.name_prefix}-report-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = local.services["report-service"].cpu
  memory                   = local.services["report-service"].memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "report-service"
      image = "${aws_ecr_repository.services["report-service"].repository_url}:${var.report_service_image_tag}"

      portMappings = [{
        containerPort = 3002
        protocol      = "tcp"
      }]

      environment = concat(local.backend_env_vars, [
        { name = "PORT", value = "3002" },
        { name = "NODE_ENV", value = var.environment }
      ])

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.services["report-service"].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:3002/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = { Name = "${local.name_prefix}-report-service-task" }
}

# ECS Services
resource "aws_ecs_service" "frontend" {
  name            = "${local.name_prefix}-frontend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = local.services["frontend"].desired
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name   = "frontend"
    container_port   = 80
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  depends_on = [aws_lb_listener.http]

  tags = { Name = "${local.name_prefix}-frontend-service" }
}

resource "aws_ecs_service" "inspection_api" {
  name            = "${local.name_prefix}-inspection-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.inspection_api.arn
  desired_count   = local.services["inspection-api"].desired
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.inspection_api.arn
    container_name   = "inspection-api"
    container_port   = 3001
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  depends_on = [aws_lb_listener.http]

  tags = { Name = "${local.name_prefix}-inspection-api-service" }
}

resource "aws_ecs_service" "report_service" {
  name            = "${local.name_prefix}-report-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.report_service.arn
  desired_count   = local.services["report-service"].desired
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.report_service.arn
    container_name   = "report-service"
    container_port   = 3002
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  depends_on = [aws_lb_listener.http]

  tags = { Name = "${local.name_prefix}-report-service-service" }
}
