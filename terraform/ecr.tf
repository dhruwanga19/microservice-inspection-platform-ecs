# terraform/ecr.tf
# ECR repositories for container images

resource "aws_ecr_repository" "services" {
  for_each = local.services

  name                 = "${local.name_prefix}-${each.key}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = { Name = "${local.name_prefix}-${each.key}" }
}

# Lifecycle policy to clean up old images
resource "aws_ecr_lifecycle_policy" "cleanup" {
  for_each   = aws_ecr_repository.services
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Output repository URLs for build scripts
output "ecr_repository_urls" {
  description = "ECR repository URLs for each service"
  value = {
    for k, v in aws_ecr_repository.services : k => v.repository_url
  }
}
