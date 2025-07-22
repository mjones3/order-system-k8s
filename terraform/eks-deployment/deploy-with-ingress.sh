#!/bin/bash

# Script to deploy the order service with ALB ingress
set -e

# Working directory
WORKDIR="/workspace"
CURRENT_DIR=$(pwd)

echo "🚀 Deploying order service with ALB ingress..."

# Initialize Terraform
echo "📝 Initializing Terraform..."
docker run --rm -v ${CURRENT_DIR}:/workspace \
  -v ~/.aws:/root/.aws \
  -w ${WORKDIR}/terraform/eks-deployment \
  hashicorp/terraform:latest init -reconfigure

# Validate Terraform configuration
echo "🔍 Validating Terraform configuration..."
docker run --rm -v ${CURRENT_DIR}:/workspace \
  -v ~/.aws:/root/.aws \
  -w ${WORKDIR}/terraform/eks-deployment \
  hashicorp/terraform:latest validate

# Plan Terraform changes
echo "📋 Planning Terraform changes..."
docker run --rm -v ${CURRENT_DIR}:/workspace \
  -v ~/.aws:/root/.aws \
  -w ${WORKDIR}/terraform/eks-deployment \
  hashicorp/terraform:latest plan \
  -target=module.alb_controller \
  -target=module.eks_order_service \
  -out=ingress.tfplan

# Apply Terraform configuration
echo "🔧 Applying Terraform configuration..."
docker run --rm -v ${CURRENT_DIR}:/workspace \
  -v ~/.aws:/root/.aws \
  -w ${WORKDIR}/terraform/eks-deployment \
  hashicorp/terraform:latest apply ingress.tfplan

# Wait for the ingress to be provisioned
echo "⏳ Waiting for ALB ingress to be provisioned (this may take a few minutes)..."
sleep 30

# Get the ingress hostname
INGRESS_HOSTNAME=$(docker run --rm -v ${CURRENT_DIR}:/workspace \
  -v ~/.aws:/root/.aws \
  -w ${WORKDIR}/terraform/eks-deployment \
  hashicorp/terraform:latest output -raw order_service_ingress_hostname 2>/dev/null || echo "")

if [ -z "$INGRESS_HOSTNAME" ]; then
  echo "⚠️ Ingress hostname not available yet. It may take a few minutes for the ALB to be provisioned."
  echo "Run the following command to check the status:"
  echo "kubectl get ingress -n order-service"
  echo "Once the ingress is provisioned, you can get the URL with:"
  echo "docker run --rm -v \$(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace/terraform/eks-deployment hashicorp/terraform:latest output order_service_url"
else
  echo "✅ Order service is now accessible at: http://$INGRESS_HOSTNAME"
  echo "You can make API requests to this endpoint, for example:"
  echo "curl -X GET http://$INGRESS_HOSTNAME/actuator/health"
fi