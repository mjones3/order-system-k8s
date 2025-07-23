#!/bin/bash

# Deploy payment service with ALB ingress using your Docker pattern
set -e

echo "🚀 Deploying payment service with ALB ingress..."

# Navigate to terraform/eks-deployment directory
cd terraform/eks-deployment

# Initialize Terraform
echo "📝 Initializing Terraform..."
docker run --rm -it \
  -v $(pwd):/workspace \
  -v ~/.aws:/root/.aws \
  -w /workspace \
  hashicorp/terraform:latest init

# Plan Terraform configuration - only target the payment service ingress
echo "📋 Planning Terraform configuration..."
docker run --rm -it \
  -v $(pwd):/workspace \
  -v ~/.aws:/root/.aws \
  -w /workspace \
  hashicorp/terraform:latest plan \
  -target=module.eks_payment_service.kubernetes_ingress_v1.payment_service_ingress \
  -var-file=terraform.tfvars \
  -out=payment-ingress.tfplan

# Apply Terraform configuration
echo "🔧 Applying Terraform configuration..."
docker run --rm -it \
  -v $(pwd):/workspace \
  -v ~/.aws:/root/.aws \
  -w /workspace \
  hashicorp/terraform:latest apply payment-ingress.tfplan

echo "✅ Deployment completed!"
echo ""
echo "⏳ The ALB may take a few minutes to be fully provisioned."
echo "To get the external URL once it's ready, run:"
echo ""
echo "cd terraform/eks-deployment"
echo "docker run --rm -v \$(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace hashicorp/terraform:latest output payment_service_url"
echo ""
echo "To check the ingress status:"
echo "kubectl get ingress -n payment-service"
echo ""
echo "Note: The ingress is configured to use HTTP only. If you need HTTPS, you'll need to create an ACM certificate and update the ingress annotations."