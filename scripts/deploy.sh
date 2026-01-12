#!/bin/bash
# Full deployment script for ECS Inspection Platform

set -e

# Configuration
AWS_REGION="${AWS_REGION:-us-east-1}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
IMAGE_TAG="${IMAGE_TAG:-$(date +%Y%m%d-%H%M%S)}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

print_banner() {
  echo ""
  echo "=================================================="
  echo "  ECS Inspection Platform Deployment"
  echo "  Environment: ${ENVIRONMENT}"
  echo "  Region: ${AWS_REGION}"
  echo "  Image Tag: ${IMAGE_TAG}"
  echo "=================================================="
  echo ""
}

# Check prerequisites
check_prerequisites() {
  log_step "Checking prerequisites..."
  
  command -v aws >/dev/null 2>&1 || { log_error "AWS CLI is required but not installed."; exit 1; }
  command -v terraform >/dev/null 2>&1 || { log_error "Terraform is required but not installed."; exit 1; }
  command -v docker >/dev/null 2>&1 || { log_error "Docker is required but not installed."; exit 1; }
  
  # Check AWS credentials
  aws sts get-caller-identity >/dev/null 2>&1 || { log_error "AWS credentials not configured."; exit 1; }
  
  # Check Docker daemon
  docker info >/dev/null 2>&1 || { log_error "Docker daemon is not running."; exit 1; }
  
  log_info "All prerequisites met!"
}

# Initialize and apply Terraform
deploy_infrastructure() {
  log_step "Deploying infrastructure with Terraform..."
  
  cd terraform
  
  # Initialize Terraform
  terraform init -upgrade
  
  # Plan and apply
  terraform plan \
    -var="environment=${ENVIRONMENT}" \
    -var="aws_region=${AWS_REGION}" \
    -out=tfplan
  
  log_warn "Review the plan above. Continue with apply? (y/n)"
  read -r response
  if [[ "$response" != "y" ]]; then
    log_info "Deployment cancelled."
    exit 0
  fi
  
  terraform apply tfplan
  
  # Save outputs
  terraform output -json > ../terraform-outputs.json
  
  cd ..
  log_info "Infrastructure deployed successfully!"
}

# Build and push Docker images
build_and_push_images() {
  log_step "Building and pushing Docker images..."
  
  export AWS_REGION
  export ENVIRONMENT
  export IMAGE_TAG
  
  ./scripts/build-push-images.sh
  
  log_info "Images built and pushed successfully!"
}

# Update ECS services with new images
update_ecs_services() {
  log_step "Updating ECS services..."
  
  CLUSTER_NAME="inspection-${ENVIRONMENT}-cluster"
  SERVICES=("frontend" "inspection-api" "report-service")
  
  for SERVICE in "${SERVICES[@]}"; do
    SERVICE_NAME="inspection-${ENVIRONMENT}-${SERVICE}"
    log_info "Forcing new deployment for ${SERVICE_NAME}..."
    
    aws ecs update-service \
      --cluster "${CLUSTER_NAME}" \
      --service "${SERVICE_NAME}" \
      --force-new-deployment \
      --region "${AWS_REGION}" \
      --no-cli-pager
  done
  
  log_info "ECS services updated!"
}

# Wait for services to stabilize
wait_for_services() {
  log_step "Waiting for services to stabilize..."
  
  CLUSTER_NAME="inspection-${ENVIRONMENT}-cluster"
  SERVICES=("inspection-${ENVIRONMENT}-frontend" "inspection-${ENVIRONMENT}-inspection-api" "inspection-${ENVIRONMENT}-report-service")
  
  for SERVICE in "${SERVICES[@]}"; do
    log_info "Waiting for ${SERVICE}..."
    aws ecs wait services-stable \
      --cluster "${CLUSTER_NAME}" \
      --services "${SERVICE}" \
      --region "${AWS_REGION}"
  done
  
  log_info "All services are stable!"
}

# Print deployment summary
print_summary() {
  log_step "Deployment Summary"
  
  if [ -f terraform-outputs.json ]; then
    APP_URL=$(jq -r '.app_url.value' terraform-outputs.json)
    ALB_DNS=$(jq -r '.alb_dns.value' terraform-outputs.json)
    
    echo ""
    echo "=================================================="
    echo "  Deployment Complete!"
    echo "=================================================="
    echo ""
    echo "  Application URL: ${APP_URL}"
    echo "  ALB DNS: ${ALB_DNS}"
    echo ""
    echo "  Test endpoints:"
    echo "    - Frontend:    ${APP_URL}/"
    echo "    - Inspections: ${APP_URL}/api/inspections"
    echo "    - Health:      ${APP_URL}/api/inspections (GET /health)"
    echo ""
    echo "=================================================="
  fi
}

# Main deployment flow
main() {
  print_banner
  check_prerequisites
  
  case "${1:-all}" in
    infra)
      deploy_infrastructure
      ;;
    images)
      build_and_push_images
      ;;
    update)
      update_ecs_services
      wait_for_services
      ;;
    all)
      deploy_infrastructure
      build_and_push_images
      update_ecs_services
      wait_for_services
      ;;
    *)
      echo "Usage: $0 {all|infra|images|update}"
      echo ""
      echo "  all    - Full deployment (default)"
      echo "  infra  - Deploy infrastructure only"
      echo "  images - Build and push images only"
      echo "  update - Update ECS services only"
      exit 1
      ;;
  esac
  
  print_summary
}

main "$@"