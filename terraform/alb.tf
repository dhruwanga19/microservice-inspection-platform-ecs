# terraform/alb.tf
# Application Load Balancer with path-based routing

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = { Name = "${local.name_prefix}-alb" }
}

# Target Groups
resource "aws_lb_target_group" "frontend" {
  name        = "${local.name_prefix}-frontend-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  tags = { Name = "${local.name_prefix}-frontend-tg" }
}

resource "aws_lb_target_group" "inspection_api" {
  name        = "${local.name_prefix}-insp-api-tg"
  port        = 3001
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  tags = { Name = "${local.name_prefix}-inspection-api-tg" }
}

resource "aws_lb_target_group" "report_service" {
  name        = "${local.name_prefix}-report-svc-tg"
  port        = 3002
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  tags = { Name = "${local.name_prefix}-report-service-tg" }
}

# HTTP Listener (default)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  # Default action - forward to frontend
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# HTTPS Listener (optional)
resource "aws_lb_listener" "https" {
  count = var.create_https_listener ? 1 : 0

  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# HTTP to HTTPS redirect (when HTTPS is enabled)
resource "aws_lb_listener_rule" "http_redirect" {
  count        = var.create_https_listener ? 1 : 0
  listener_arn = aws_lb_listener.http.arn
  priority     = 1

  action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}

# ==================== PATH-BASED ROUTING RULES ====================

# Priority 1: /api/reports/* -> report-service
resource "aws_lb_listener_rule" "reports" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.report_service.arn
  }

  condition {
    path_pattern {
      values = ["/api/reports/*"]
    }
  }
}

# Priority 2: /api/inspections/* -> inspection-api
resource "aws_lb_listener_rule" "inspections" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.inspection_api.arn
  }

  condition {
    path_pattern {
      values = ["/api/inspections", "/api/inspections/*"]
    }
  }
}

# Priority 3: /api/presigned-url -> inspection-api
resource "aws_lb_listener_rule" "presigned_url" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 30

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.inspection_api.arn
  }

  condition {
    path_pattern {
      values = ["/api/presigned-url"]
    }
  }
}

# HTTPS listener rules (duplicate for HTTPS if enabled)
resource "aws_lb_listener_rule" "reports_https" {
  count        = var.create_https_listener ? 1 : 0
  listener_arn = aws_lb_listener.https[0].arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.report_service.arn
  }

  condition {
    path_pattern {
      values = ["/api/reports/*"]
    }
  }
}

resource "aws_lb_listener_rule" "inspections_https" {
  count        = var.create_https_listener ? 1 : 0
  listener_arn = aws_lb_listener.https[0].arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.inspection_api.arn
  }

  condition {
    path_pattern {
      values = ["/api/inspections", "/api/inspections/*"]
    }
  }
}

resource "aws_lb_listener_rule" "presigned_url_https" {
  count        = var.create_https_listener ? 1 : 0
  listener_arn = aws_lb_listener.https[0].arn
  priority     = 30

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.inspection_api.arn
  }

  condition {
    path_pattern {
      values = ["/api/presigned-url"]
    }
  }
}

# Output ALB DNS name
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "application_url" {
  description = "URL to access the application"
  value       = "http://${aws_lb.main.dns_name}"
}
