# terraform/outputs.tf
# Output values for reference and scripts

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  value       = aws_ecs_cluster.main.arn
}

output "alb_arn" {
  description = "ALB ARN"
  value       = aws_lb.main.arn
}

output "alb_dns" {
  description = "ALB DNS name"
  value       = aws_lb.main.dns_name
}

output "app_url" {
  description = "Application URL"
  value       = "http://${aws_lb.main.dns_name}"
}

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.inspections.name
}

output "s3_bucket_name" {
  description = "S3 bucket for images"
  value       = aws_s3_bucket.images.id
}

output "sns_topic_arn" {
  description = "SNS topic ARN"
  value       = aws_sns_topic.notifications.arn
}

output "sqs_queue_url" {
  description = "SQS queue URL"
  value       = aws_sqs_queue.notifications.url
}

output "ecr_repositories" {
  description = "ECR repository URLs"
  value = {
    frontend       = aws_ecr_repository.services["frontend"].repository_url
    inspection_api = aws_ecr_repository.services["inspection-api"].repository_url
    report_service = aws_ecr_repository.services["report-service"].repository_url
  }
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.send_notification.function_name
}

# Useful commands output
output "useful_commands" {
  description = "Helpful commands for deployment"
  value       = <<-EOT
    
    # Login to ECR
    aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com
    
    # View ECS service logs
    aws logs tail /ecs/${local.name_prefix}/inspection-api --follow
    
    # Update ECS service
    aws ecs update-service --cluster ${aws_ecs_cluster.main.name} --service ${local.name_prefix}-inspection-api --force-new-deployment
    
    # Check service health
    curl http://${aws_lb.main.dns_name}/api/inspections
    
  EOT
}
