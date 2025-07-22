#!/bin/bash

# Deploy order service with ALB ingress using your Docker pattern
set -e

echo "🚀 Deploying order service with ALB ingress..."

# Navigate to terraform/eks-deployment directory
cd terraform/eks-deployment

# Initialize Terraform
echo "📝 Initializing Terraform..."
docker run --rm -it \
  -v $(pwd):/workspace \
  -v ~/.aws:/root/.aws \
  -w /workspace \
  hashicorp/terraform:latest init

# Plan Terraform configuration
echo "📋 Planning Terraform configuration..."
docker run --rm -it \
  -v $(pwd):/workspace \
  -v ~/.aws:/root/.aws \
  -w /workspace \
  hashicorp/terraform:latest plan \
  -target=module.alb_controller \
  -target=module.eks_order_service \
  -var-file=terraform.tfvars \
  -out=ingress.tfplan

# Apply Terraform configuration
echo "🔧 Applying Terraform configuration..."
docker run --rm -it \
  -v $(pwd):/workspace \
  -v ~/.aws:/root/.aws \
  -w /workspace \
  hashicorp/terraform:latest apply ingress.tfplan

echo "✅ Deployment completed!"
echo ""
echo "⏳ The ALB may take a few minutes to be fully provisioned."
echo "To get the external URL once it's ready, run:"
echo ""
echo "cd terraform/eks-deployment"
echo "docker run --rm -v \$(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace hashicorp/terraform:latest output order_service_url"
echo ""
echo "To check the ingress status:"
echo "kubectl get ingress -n order-service"