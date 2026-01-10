# terraform/autoscaling.tf
# Auto Scaling policies for ECS services

# ==================== FRONTEND ====================
resource "aws_appautoscaling_target" "frontend" {
  max_capacity       = local.services["frontend"].max
  min_capacity       = local.services["frontend"].min
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.frontend.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "frontend_cpu" {
  name               = "${local.name_prefix}-frontend-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.frontend.resource_id
  scalable_dimension = aws_appautoscaling_target.frontend.scalable_dimension
  service_namespace  = aws_appautoscaling_target.frontend.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

resource "aws_appautoscaling_policy" "frontend_memory" {
  name               = "${local.name_prefix}-frontend-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.frontend.resource_id
  scalable_dimension = aws_appautoscaling_target.frontend.scalable_dimension
  service_namespace  = aws_appautoscaling_target.frontend.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = 80.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# ==================== INSPECTION API ====================
resource "aws_appautoscaling_target" "inspection_api" {
  max_capacity       = local.services["inspection-api"].max
  min_capacity       = local.services["inspection-api"].min
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.inspection_api.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "inspection_api_cpu" {
  name               = "${local.name_prefix}-inspection-api-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.inspection_api.resource_id
  scalable_dimension = aws_appautoscaling_target.inspection_api.scalable_dimension
  service_namespace  = aws_appautoscaling_target.inspection_api.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

resource "aws_appautoscaling_policy" "inspection_api_memory" {
  name               = "${local.name_prefix}-inspection-api-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.inspection_api.resource_id
  scalable_dimension = aws_appautoscaling_target.inspection_api.scalable_dimension
  service_namespace  = aws_appautoscaling_target.inspection_api.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = 80.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# Request count based scaling for inspection-api
resource "aws_appautoscaling_policy" "inspection_api_requests" {
  name               = "${local.name_prefix}-inspection-api-request-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.inspection_api.resource_id
  scalable_dimension = aws_appautoscaling_target.inspection_api.scalable_dimension
  service_namespace  = aws_appautoscaling_target.inspection_api.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${aws_lb.main.arn_suffix}/${aws_lb_target_group.inspection_api.arn_suffix}"
    }
    target_value       = 1000 # Scale when reaching 1000 requests per target
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# ==================== REPORT SERVICE ====================
resource "aws_appautoscaling_target" "report_service" {
  max_capacity       = local.services["report-service"].max
  min_capacity       = local.services["report-service"].min
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.report_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "report_service_cpu" {
  name               = "${local.name_prefix}-report-service-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.report_service.resource_id
  scalable_dimension = aws_appautoscaling_target.report_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.report_service.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

resource "aws_appautoscaling_policy" "report_service_memory" {
  name               = "${local.name_prefix}-report-service-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.report_service.resource_id
  scalable_dimension = aws_appautoscaling_target.report_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.report_service.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = 80.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
