# terraform/variables.tf
# Input variables for the infrastructure

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets (costs ~$32/month)"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT Gateway instead of one per AZ (saves cost)"
  type        = bool
  default     = true
}

variable "domain_name" {
  description = "Domain name for Route 53 (optional, leave empty to skip)"
  type        = string
  default     = ""
}

variable "create_https_listener" {
  description = "Create HTTPS listener (requires ACM certificate)"
  type        = bool
  default     = false
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS (required if create_https_listener is true)"
  type        = string
  default     = ""
}

# Container image tags - updated during CI/CD
variable "frontend_image_tag" {
  description = "Docker image tag for frontend"
  type        = string
  default     = "latest"
}

variable "inspection_api_image_tag" {
  description = "Docker image tag for inspection-api"
  type        = string
  default     = "latest"
}

variable "report_service_image_tag" {
  description = "Docker image tag for report-service"
  type        = string
  default     = "latest"
}
