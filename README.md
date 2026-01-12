# Microservice Inspection Platform on AWS ECS

A production-ready, cloud-native building inspection platform built with microservices architecture and deployed on AWS ECS (Elastic Container Service). This platform enables inspectors to create, manage, and generate reports for property inspections with image uploads and automated notifications.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Architecture Decisions](#architecture-decisions)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [Services](#services)
- [Infrastructure](#infrastructure)
- [API Documentation](#api-documentation)
- [Development](#development)
- [Deployment](#deployment)
- [Monitoring & Logging](#monitoring--logging)
- [Cost Optimization](#cost-optimization)
- [Security](#security)
- [Troubleshooting](#troubleshooting)

## Overview

This platform provides a complete solution for building inspections with the following capabilities:

- **Inspection Management**: Create, view, and update property inspections
- **Checklist System**: Track condition of roof, foundation, plumbing, electrical, and HVAC
- **Image Upload**: Secure image uploads with presigned S3 URLs
- **Report Generation**: Automated report generation with overall condition assessment
- **Notifications**: Event-driven email notifications via SNS/SQS/Lambda
- **Scalability**: Auto-scaling microservices on AWS ECS Fargate
- **High Availability**: Multi-AZ deployment with load balancing

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Internet                              │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │  Application Load    │
              │  Balancer (ALB)      │
              └──────────┬───────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
        ▼                ▼                ▼
   ┌─────────┐    ┌──────────────┐  ┌──────────────┐
   │Frontend │    │ Inspection API │  │Report Service│
   │(React)  │    │  (Express)   │  │  (Express)   │
   └────┬────┘    └──────┬───────┘  └──────┬───────┘
        │                │                 │
        └────────────────┼─────────────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
        ▼                ▼                ▼
   ┌──────────┐    ┌──────────┐   ┌──────────┐
   │ DynamoDB │    │    S3     │   │   SNS    │
   │  Table   │    │  Bucket   │   │  Topic   │
   └──────────┘    └──────────┘   └─────┬─────┘
                                        │
                                        ▼
                                  ┌──────────┐
                                  │   SQS    │
                                  │  Queue   │
                                  └─────┬────┘
                                        │
                                        ▼
                                  ┌──────────┐
                                  │  Lambda   │
                                  │(Send Email)│
                                  └──────────┘
```

### Component Details

1. **Frontend Service**: React application served via Nginx, handles UI interactions
2. **Inspection API**: RESTful API for CRUD operations on inspections and presigned URL generation
3. **Report Service**: Generates inspection reports and publishes events to SNS
4. **DynamoDB**: NoSQL database storing inspection data with GSI for status queries
5. **S3**: Object storage for inspection images with versioning and encryption
6. **SNS/SQS/Lambda**: Event-driven notification system for report generation events
7. **ECS Fargate**: Container orchestration with serverless compute
8. **Application Load Balancer**: Path-based routing and health checks

## Architecture Decisions

### Why Microservices?

- **Independent Scaling**: Each service can scale based on its own load patterns
- **Technology Flexibility**: Services can use different technologies if needed
- **Fault Isolation**: Failure in one service doesn't bring down the entire platform
- **Team Autonomy**: Different teams can work on different services independently
- **Deployment Independence**: Services can be deployed separately without affecting others

### Why AWS ECS Fargate?

- **Serverless Containers**: No need to manage EC2 instances or clusters
- **Cost Efficiency**: Pay only for running containers, no idle infrastructure
- **Auto Scaling**: Built-in integration with Application Auto Scaling
- **Security**: Containers run in isolated environments with IAM roles
- **Simplified Operations**: No need to patch or maintain underlying infrastructure

### Why DynamoDB?

- **Serverless**: No database management overhead
- **Performance**: Single-digit millisecond latency at any scale
- **Cost-Effective**: Pay-per-request pricing model for variable workloads
- **Scalability**: Automatic scaling without capacity planning
- **GSI Support**: Efficient querying by status for filtering inspections

### Why S3 for Images?

- **Durability**: 99.999999999% (11 9's) durability
- **Cost-Effective**: Cheaper than storing images in database
- **Presigned URLs**: Secure, time-limited access without exposing bucket
- **Versioning**: Automatic versioning for image history
- **CDN Ready**: Easy integration with CloudFront for global distribution

### Why Event-Driven Notifications (SNS/SQS/Lambda)?

- **Decoupling**: Report service doesn't need to wait for email delivery
- **Reliability**: SQS provides message persistence and retry logic
- **Scalability**: Lambda automatically scales with message volume
- **Cost-Effective**: Pay only for actual notifications sent
- **Flexibility**: Easy to add more notification channels (SMS, push, etc.)

### Why Application Load Balancer?

- **Path-Based Routing**: Single entry point with intelligent routing
- **Health Checks**: Automatic detection and removal of unhealthy targets
- **SSL/TLS Termination**: Centralized certificate management
- **Integration**: Native integration with ECS service discovery
- **Cost-Effective**: Pay per hour and per LCU (Load Balancer Capacity Unit)

### Why VPC with Private Subnets?

- **Security**: ECS tasks run in private subnets, not directly exposed to internet
- **Network Isolation**: Isolated network environment for resources
- **NAT Gateway**: Controlled outbound internet access
- **VPC Endpoints**: Private connectivity to AWS services (reduces NAT costs)
- **Compliance**: Meets security requirements for production workloads

## Prerequisites

Before deploying this platform, ensure you have:

- **AWS Account** with appropriate permissions
- **AWS CLI** installed and configured (`aws configure`)
- **Terraform** >= 1.0 installed
- **Docker** installed and running
- **Node.js** >= 20.0.0 (for local development)
- **Git** for cloning the repository

### AWS Permissions Required

Your AWS credentials need permissions for:
- ECS (clusters, services, task definitions)
- ECR (repositories, image push/pull)
- EC2 (VPC, subnets, security groups, load balancers)
- DynamoDB (table creation and management)
- S3 (bucket creation and management)
- SNS/SQS (topic and queue creation)
- Lambda (function creation and execution)
- IAM (role and policy creation)
- CloudWatch (log groups)

## Quick Start

### 1. Clone the Repository

```bash
git clone <repository-url>
cd microservice-inspection-platform-ecs
```

### 2. Configure AWS Credentials

```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Enter default region (e.g., us-east-1)
# Enter default output format (json)
```

### 3. Deploy Infrastructure

```bash
# Full deployment (infrastructure + images + services)
./scripts/deploy.sh all

# Or deploy step by step:
./scripts/deploy.sh infra    # Deploy infrastructure only
./scripts/deploy.sh images   # Build and push images
./scripts/deploy.sh update   # Update ECS services
```

### 4. Access the Application

After deployment, Terraform will output the ALB DNS name. Access the application at:

```
http://<alb-dns-name>/
```

## Project Structure

```
microservice-inspection-platform-ecs/
├── lambda/
│   └── sendNotification/      # Lambda function for email notifications
│       └── index.js
├── scripts/
│   ├── build-push-images.sh   # Build and push Docker images to ECR
│   └── deploy.sh               # Full deployment orchestration
├── services/
│   ├── frontend/               # React frontend application
│   │   ├── Dockerfile
│   │   ├── nginx.conf
│   │   ├── package.json
│   │   └── src/
│   ├── inspection-api/         # Inspection CRUD API
│   │   ├── Dockerfile
│   │   ├── package.json
│   │   └── src/
│   │       └── index.js
│   └── report-service/         # Report generation service
│       ├── Dockerfile
│       ├── package.json
│       └── src/
│           └── index.js
└── terraform/
    ├── alb.tf                  # Application Load Balancer
    ├── autoscaling.tf          # Auto-scaling policies
    ├── data-layer.tf            # DynamoDB, S3, SNS, SQS, Lambda
    ├── ecr.tf                   # ECR repositories
    ├── ecs.tf                   # ECS cluster, services, task definitions
    ├── iam.tf                   # IAM roles and policies
    ├── main.tf                  # Main configuration
    ├── outputs.tf               # Terraform outputs
    ├── security-groups.tf       # Security group rules
    ├── variables.tf             # Input variables
    └── vpc.tf                   # VPC, subnets, NAT, endpoints
```

## Services

### Frontend Service

**Technology**: React 19, Vite, Tailwind CSS, Nginx  
**Port**: 80  
**Purpose**: User interface for managing inspections

**Features**:
- Inspection list view with status filtering
- Create new inspections
- Edit inspection details and checklist
- Upload images via presigned URLs
- Generate and view reports

**Local Development**:
```bash
cd services/frontend
npm install
npm run dev
```

### Inspection API Service

**Technology**: Node.js, Express  
**Port**: 3001  
**Purpose**: Core API for inspection management

**Endpoints**:
- `POST /api/inspections` - Create new inspection
- `GET /api/inspections` - List all inspections (optional `?status=DRAFT`)
- `GET /api/inspections/:id` - Get inspection details
- `PUT /api/inspections/:id` - Update inspection
- `POST /api/presigned-url` - Generate S3 presigned URL for image upload
- `GET /health` - Health check

**Local Development**:
```bash
cd services/inspection-api
npm install
npm run dev
```

### Report Service

**Technology**: Node.js, Express  
**Port**: 3002  
**Purpose**: Report generation and event publishing

**Endpoints**:
- `POST /api/reports/:inspectionId` - Generate report for inspection
- `GET /api/reports/:inspectionId` - Retrieve generated report
- `GET /health` - Health check

**Local Development**:
```bash
cd services/report-service
npm install
npm run dev
```

## Infrastructure

### Network Architecture

- **VPC**: Custom VPC with CIDR 10.0.0.0/16 (configurable)
- **Public Subnets**: For ALB and NAT Gateway (2 AZs)
- **Private Subnets**: For ECS tasks (2 AZs)
- **NAT Gateway**: For outbound internet access from private subnets
- **VPC Endpoints**: For DynamoDB, S3, ECR, CloudWatch Logs, SNS (reduces NAT costs)

### Compute

- **ECS Cluster**: Fargate-based cluster with Container Insights enabled
- **Task Definitions**: Separate definitions for each service
- **Services**: ECS services with desired count and auto-scaling
- **Capacity Providers**: FARGATE (primary) and FARGATE_SPOT (optional)

### Storage

- **DynamoDB**: On-demand billing, GSI for status queries, Point-in-Time Recovery enabled
- **S3**: Image storage with versioning, encryption, and CORS configuration

### Messaging

- **SNS Topic**: For publishing report generation events
- **SQS Queue**: For reliable message delivery with DLQ
- **Lambda Function**: Processes SQS messages and sends notifications

### Load Balancing

- **ALB**: Application Load Balancer with path-based routing
- **Target Groups**: Separate target groups for each service
- **Health Checks**: Configured for each service
- **HTTPS**: Optional HTTPS listener (requires ACM certificate)

## API Documentation

### Create Inspection

```http
POST /api/inspections
Content-Type: application/json

{
  "propertyAddress": "123 Main St, City, State",
  "inspectorName": "John Doe",
  "inspectorEmail": "john@example.com",
  "clientName": "Jane Smith",
  "clientEmail": "jane@example.com"
}
```

**Response**:
```json
{
  "message": "Inspection created successfully",
  "inspection": {
    "inspectionId": "insp_abc12345",
    "propertyAddress": "123 Main St, City, State",
    "inspectorName": "John Doe",
    "status": "DRAFT",
    "createdAt": "2024-01-15T10:30:00Z"
  }
}
```

### List Inspections

```http
GET /api/inspections
GET /api/inspections?status=DRAFT
```

**Response**:
```json
{
  "count": 2,
  "inspections": [
    {
      "inspectionId": "insp_abc12345",
      "propertyAddress": "123 Main St",
      "status": "DRAFT",
      "createdAt": "2024-01-15T10:30:00Z"
    }
  ]
}
```

### Update Inspection

```http
PUT /api/inspections/:inspectionId
Content-Type: application/json

{
  "checklist": {
    "roof": "Good",
    "foundation": "Fair",
    "plumbing": "Good",
    "electrical": "Poor",
    "hvac": "Good"
  },
  "notes": "Overall condition is good with minor electrical issues.",
  "status": "SUBMITTED"
}
```

### Generate Presigned URL

```http
POST /api/presigned-url
Content-Type: application/json

{
  "inspectionId": "insp_abc12345",
  "fileName": "roof-image.jpg",
  "contentType": "image/jpeg",
  "operation": "upload"
}
```

**Response**:
```json
{
  "uploadUrl": "https://s3.amazonaws.com/...",
  "s3Key": "inspections/insp_abc12345/img_xyz789.jpg",
  "imageId": "img_xyz789",
  "expiresIn": 300
}
```

### Generate Report

```http
POST /api/reports/:inspectionId
```

**Response**:
```json
{
  "message": "Report generated successfully",
  "report": {
    "reportId": "report_insp_abc12345",
    "inspectionId": "insp_abc12345",
    "generatedAt": "2024-01-15T11:00:00Z",
    "summary": {
      "overallCondition": "Good",
      "checklist": { ... },
      "totalImages": 5
    }
  }
}
```

## Development

### Local Development Setup

1. **Start Services Locally**:

```bash
# Terminal 1: Inspection API
cd services/inspection-api
npm install
npm run dev

# Terminal 2: Report Service
cd services/report-service
npm install
npm run dev

# Terminal 3: Frontend
cd services/frontend
npm install
npm run dev
```

2. **Configure Environment Variables**:

Create `.env` files in each service directory:

**services/inspection-api/.env**:
```
TABLE_NAME=InspectionsTable-dev
IMAGE_BUCKET_NAME=inspection-images-dev
AWS_REGION=us-east-1
PORT=3001
NODE_ENV=development
```

**services/report-service/.env**:
```
TABLE_NAME=InspectionsTable-dev
SNS_TOPIC_ARN=arn:aws:sns:us-east-1:123456789012:notifications-dev
AWS_REGION=us-east-1
PORT=3002
NODE_ENV=development
```

3. **Set Up Local DynamoDB** (optional):

Use DynamoDB Local or AWS DynamoDB for development.

### Building Docker Images

```bash
# Build all images
./scripts/build-push-images.sh

# Or build individually
cd services/frontend
docker build -t inspection-frontend:latest .

cd services/inspection-api
docker build -t inspection-api:latest .

cd services/report-service
docker build -t report-service:latest .
```

### Testing

```bash
# Test Inspection API
curl http://localhost:3001/health

# Test Report Service
curl http://localhost:3002/health

# Create an inspection
curl -X POST http://localhost:3001/api/inspections \
  -H "Content-Type: application/json" \
  -d '{
    "propertyAddress": "123 Test St",
    "inspectorName": "Test Inspector",
    "inspectorEmail": "test@example.com"
  }'
```

## Deployment

### Initial Deployment

1. **Review Terraform Variables**:

Edit `terraform/variables.tf` or use `terraform.tfvars`:

```hcl
aws_region = "us-east-1"
environment = "prod"
vpc_cidr = "10.0.0.0/16"
```

2. **Deploy Infrastructure**:

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

3. **Build and Push Images**:

```bash
./scripts/build-push-images.sh
```

4. **Update ECS Services**:

```bash
aws ecs update-service \
  --cluster inspection-prod-cluster \
  --service inspection-prod-frontend \
  --force-new-deployment
```

### Updating Services

```bash
# Update image tags in terraform/variables.tf or use -var flags
terraform apply \
  -var="frontend_image_tag=v1.2.0" \
  -var="inspection_api_image_tag=v1.2.0" \
  -var="report_service_image_tag=v1.2.0"
```

### CI/CD Integration

The deployment scripts are designed to be integrated into CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
- name: Deploy to ECS
  run: |
    ./scripts/deploy.sh all
  env:
    AWS_REGION: us-east-1
    ENVIRONMENT: prod
```

## Monitoring & Logging

### CloudWatch Logs

All services log to CloudWatch Log Groups:
- `/ecs/inspection-{env}/frontend`
- `/ecs/inspection-{env}/inspection-api`
- `/ecs/inspection-{env}/report-service`
- `/aws/lambda/inspection-{env}-sendNotification`

### Container Insights

ECS Container Insights is enabled for the cluster, providing:
- CPU and memory utilization
- Task count and health
- Service-level metrics

### Health Checks

All services expose `/health` endpoints:
- Frontend: `GET /`
- Inspection API: `GET /health`
- Report Service: `GET /health`

### Viewing Logs

```bash
# View Inspection API logs
aws logs tail /ecs/inspection-prod/inspection-api --follow

# View Lambda logs
aws logs tail /aws/lambda/inspection-prod-sendNotification --follow
```

## Cost Optimization

### Current Optimizations

1. **DynamoDB On-Demand**: Pay only for actual requests
2. **Fargate Spot**: Optional capacity provider for cost savings
3. **Single NAT Gateway**: Shared NAT Gateway across AZs (saves ~$32/month)
4. **VPC Endpoints**: Reduces NAT Gateway data transfer costs
5. **S3 Lifecycle Policies**: Can be added to transition old images to Glacier

### Estimated Monthly Costs (Production)

- **ECS Fargate**: ~$50-100 (depending on traffic)
- **ALB**: ~$20-30
- **DynamoDB**: ~$5-20 (on-demand pricing)
- **S3**: ~$5-15 (depending on storage)
- **NAT Gateway**: ~$32 (if enabled)
- **CloudWatch Logs**: ~$5-10
- **Lambda**: ~$1-5 (pay per invocation)

**Total**: ~$118-212/month for moderate traffic

### Cost Reduction Tips

1. Use Fargate Spot for non-critical workloads
2. Disable NAT Gateway for development environments
3. Set up S3 lifecycle policies for old images
4. Use CloudWatch Logs retention policies
5. Consider Reserved Capacity for predictable workloads

## Security

### Current Security Measures

1. **Private Subnets**: ECS tasks run in private subnets
2. **Security Groups**: Restrictive firewall rules
3. **IAM Roles**: Least privilege access for services
4. **S3 Encryption**: Server-side encryption enabled
5. **VPC Endpoints**: Private connectivity to AWS services
6. **HTTPS Support**: Optional HTTPS listener (configure certificate)

### Security Best Practices

1. **Enable HTTPS**: Configure ACM certificate and HTTPS listener
2. **WAF**: Add AWS WAF for DDoS protection
3. **Secrets Management**: Use AWS Secrets Manager for sensitive data
4. **VPC Flow Logs**: Enable for network traffic monitoring
5. **CloudTrail**: Enable for API call auditing
6. **Regular Updates**: Keep dependencies and base images updated

### IAM Roles

- **ECS Execution Role**: For pulling images and writing logs
- **ECS Task Role**: For accessing DynamoDB, S3, SNS
- **Lambda Execution Role**: For SQS access and SES (if configured)

## Troubleshooting

### Service Not Starting

1. Check CloudWatch Logs:
```bash
aws logs tail /ecs/inspection-prod/inspection-api --follow
```

2. Check ECS Service Events:
```bash
aws ecs describe-services \
  --cluster inspection-prod-cluster \
  --services inspection-prod-inspection-api
```

3. Verify Task Definition:
```bash
aws ecs describe-task-definition \
  --task-definition inspection-prod-inspection-api
```

### Health Check Failures

1. Verify security group rules allow ALB → ECS traffic
2. Check service logs for errors
3. Verify health check path is correct
4. Ensure service is listening on correct port

### Image Pull Errors

1. Verify ECR repository exists
2. Check IAM execution role has ECR permissions
3. Verify image tag exists in ECR
4. Check VPC endpoint for ECR is configured

### DynamoDB Connection Issues

1. Verify VPC endpoint for DynamoDB is configured
2. Check IAM task role has DynamoDB permissions
3. Verify table name in environment variables
4. Check security group allows outbound HTTPS

### S3 Upload Failures

1. Verify presigned URL hasn't expired
2. Check S3 bucket CORS configuration
3. Verify IAM permissions for S3
4. Check bucket name in environment variables

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

See [LICENSE](LICENSE) file for details.

## Support

For issues and questions:
- Open an issue on GitHub
- Check CloudWatch Logs for service errors
- Review Terraform outputs for resource information

---

**Built with**: React, Node.js, Express, AWS ECS, Terraform, DynamoDB, S3, SNS, SQS, Lambda
