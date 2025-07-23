#!/bin/bash

# Deploy inventory service with ALB ingress using your Docker pattern
set -e

echo "🚀 Deploying inventory service with ALB ingress..."

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
  -target=module.eks_inventory_service \
  -var-file=terraform.tfvars \
  -out=inventory-ingress.tfplan

# Apply Terraform configuration
echo "🔧 Applying Terraform configuration..."
docker run --rm -it \
  -v $(pwd):/workspace \
  -v ~/.aws:/root/.aws \
  -w /workspace \
  hashicorp/terraform:latest apply inventory-ingress.tfplan

echo "✅ Deployment completed!"
echo ""
echo "⏳ The ALB may take a few minutes to be fully provisioned."
echo "To get the external URL once it's ready, run:"
echo ""
echo "cd terraform/eks-deployment"
echo "docker run --rm -v \$(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace hashicorp/terraform:latest output inventory_service_url"
echo ""
echo "To check the ingress status:"
echo "kubectl get ingress -n inventory-service"
echo ""
echo "Note: The ingress is configured to use HTTP only. If you need HTTPS, you'll need to create an ACM certificate and update the ingress annotations."