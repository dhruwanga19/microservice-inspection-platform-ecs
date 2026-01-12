# ECS Microservices Inspection Platform

A containerized microservices architecture for the Building Inspection Platform, deployed on AWS ECS Fargate with Terraform.

## 🎯 Project Deliverables

| Deliverable              | Location                   | Description                                 |
| ------------------------ | -------------------------- | ------------------------------------------- |
| **Dockerfiles**          | `services/*/Dockerfile`    | Multi-stage builds for all 3 services       |
| **ECS Task Definitions** | `terraform/ecs.tf`         | Fargate task definitions with health checks |
| **ALB Configuration**    | `terraform/alb.tf`         | Path-based routing rules                    |
| **Scaling Policies**     | `terraform/autoscaling.tf` | CPU, memory, and request-based scaling      |
| **Full Terraform**       | `terraform/*.tf`           | Complete infrastructure as code             |

## 🏗️ Architecture

```
                         Route 53 (optional)
                               │
                    ┌──────────▼──────────┐
                    │         ALB         │
                    │   (Path Routing)    │
                    └──────────┬──────────┘
           ┌───────────────────┼───────────────────┐
           │                   │                   │
           ▼                   ▼                   ▼
    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
    │  Frontend   │    │ Inspection  │    │   Report    │
    │   (Nginx)   │    │    API      │    │  Service    │
    │   Port 80   │    │  Port 3001  │    │  Port 3002  │
    └─────────────┘    └──────┬──────┘    └──────┬──────┘
                              │                   │
                    ┌─────────┴───────────────────┘
                    ▼
           ┌───────────────┐
           │   DynamoDB    │─────┐
           │   S3 Images   │     │
           │   SNS/SQS     │     │
           └───────┬───────┘     │
                   │             │
                   ▼             │
           ┌───────────────┐     │
           │    Lambda     │◄────┘
           │ Notification  │
           └───────────────┘
```

## 🚀 Quick Start

### Prerequisites

- AWS CLI v2 configured
- Terraform v1.0+
- Docker

### Deploy

```bash
# 1. Clone repository
git clone https://github.com/dhruwanga19/microservice-inspection-platform-ecs.git
cd microservice-inspection-platform-ecs

# 2. Initialize Terraform
cd terraform
terraform init

# 3. Deploy infrastructure
terraform apply -var="environment=dev"

# 4. Build and push images
cd ..
./scripts/build-push-images.sh

# 5. Update ECS services
./scripts/deploy.sh update

# 6. Access application
terraform -chdir=terraform output app_url
```

## 📁 Project Structure

```
ecs-inspection-platform/
├── terraform/
│   ├── main.tf              # Provider, locals
│   ├── variables.tf         # Input variables
│   ├── outputs.tf           # Output values
│   ├── vpc.tf               # VPC, subnets, NAT
│   ├── security-groups.tf   # Security groups
│   ├── ecr.tf               # ECR repositories
│   ├── ecs.tf               # Cluster, tasks, services
│   ├── alb.tf               # Load balancer, routing
│   ├── autoscaling.tf       # Auto scaling policies
│   ├── data-layer.tf        # DynamoDB, S3, SNS, SQS, Lambda
│   └── iam.tf               # IAM roles and policies
├── services/
│   ├── frontend/            # React + Nginx
│   ├── inspection-api/      # Express.js CRUD
│   └── report-service/      # Express.js Reports
├── lambda/
│   └── sendNotification/    # SQS-triggered Lambda
├── scripts/
│   ├── build-push-images.sh
│   └── deploy.sh
└── docs/
    └── DEPLOYMENT.md
```

## 🔀 ALB Routing

| Priority | Path Pattern         | Target Service |
| -------- | -------------------- | -------------- |
| 10       | `/api/reports/*`     | report-service |
| 20       | `/api/inspections/*` | inspection-api |
| 30       | `/api/presigned-url` | inspection-api |
| Default  | `/*`                 | frontend       |

## 📊 Auto Scaling

Each service has:

- **CPU-based scaling**: Target 70% utilization
- **Memory-based scaling**: Target 80% utilization
- **Request-based scaling** (inspection-api): 1000 requests/target

| Service        | Min | Max |
| -------------- | --- | --- |
| frontend       | 1   | 3   |
| inspection-api | 1   | 5   |
| report-service | 1   | 3   |

## 💰 Estimated Costs

| Resource    | Est. Monthly |
| ----------- | ------------ |
| ECS Fargate | $15-30       |
| ALB         | $16-25       |
| NAT Gateway | $32          |
| DynamoDB    | Free tier    |
| S3          | Free tier    |

**Total: ~$60-80/month**

## 🧹 Cleanup

```bash
./scripts/cleanup.sh
```

## 📖 Documentation

- [Deployment Guide](https://claude.ai/chat/docs/DEPLOYMENT.md)
- [Architecture Overview](https://claude.ai/chat/docs/ARCHITECTURE.md)

## 📝 License

MIT
