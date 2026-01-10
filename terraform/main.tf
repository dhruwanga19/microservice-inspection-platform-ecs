# terraform/main.tf
# Main Terraform configuration for ECS Inspection Platform

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "inspection-platform"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# Local values used across resources
locals {
  name_prefix = "inspection-${var.environment}"

  # Service definitions
  services = {
    frontend = {
      port        = 80
      cpu         = 256
      memory      = 512
      desired     = 1
      min         = 1
      max         = 3
      health_path = "/"
    }
    inspection-api = {
      port        = 3001
      cpu         = 256
      memory      = 512
      desired     = 1
      min         = 1
      max         = 5
      health_path = "/health"
    }
    report-service = {
      port        = 3002
      cpu         = 256
      memory      = 512
      desired     = 1
      min         = 1
      max         = 3
      health_path = "/health"
    }
  }

  # Common environment variables for backend services
  backend_env_vars = [
    { name = "TABLE_NAME", value = aws_dynamodb_table.inspections.name },
    { name = "IMAGE_BUCKET_NAME", value = aws_s3_bucket.images.id },
    { name = "SNS_TOPIC_ARN", value = aws_sns_topic.notifications.arn },
    { name = "AWS_REGION", value = var.aws_region }
  ]
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
