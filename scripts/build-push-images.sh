#!/bin/bash
# Build and push Docker images to ECR

set -e

# Configuration
AWS_REGION="${AWS_REGION:-us-east-1}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
NAME_PREFIX="inspection-${ENVIRONMENT}"

log_info "AWS Account: ${AWS_ACCOUNT_ID}"
log_info "ECR Registry: ${ECR_REGISTRY}"
log_info "Image Tag: ${IMAGE_TAG}"

# Login to ECR
log_info "Logging into ECR..."
aws ecr get-login-password --region ${AWS_REGION} | \
  docker login --username AWS --password-stdin ${ECR_REGISTRY}

# Services to build
SERVICES=("frontend" "inspection-api" "report-service")

# Build and push each service
for SERVICE in "${SERVICES[@]}"; do
  log_info "=========================================="
  log_info "Building ${SERVICE}..."
  log_info "=========================================="
  
  SERVICE_DIR="services/${SERVICE}"
  ECR_REPO="${ECR_REGISTRY}/${NAME_PREFIX}-${SERVICE}"
  
  if [ ! -d "${SERVICE_DIR}" ]; then
    log_error "Service directory not found: ${SERVICE_DIR}"
    exit 1
  fi
  
  # Build the image -- targeting linux/amd64 for fargate compatibility
  docker build \
    --platform linux/amd64 \
    -t "${SERVICE}:${IMAGE_TAG}" \
    -t "${ECR_REPO}:${IMAGE_TAG}" \
    -t "${ECR_REPO}:latest" \
    "${SERVICE_DIR}"
  
  log_info "Pushing ${SERVICE} to ECR..."
  
  # Push both tags
  docker push "${ECR_REPO}:${IMAGE_TAG}"
  docker push "${ECR_REPO}:latest"
  
  log_info "${SERVICE} pushed successfully!"
done

log_info "=========================================="
log_info "All images built and pushed successfully!"
log_info "=========================================="

# Output image URIs for reference
echo ""
log_info "Image URIs:"
for SERVICE in "${SERVICES[@]}"; do
  echo "  ${SERVICE}: ${ECR_REGISTRY}/${NAME_PREFIX}-${SERVICE}:${IMAGE_TAG}"
done