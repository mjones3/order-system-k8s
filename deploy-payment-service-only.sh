#!/bin/bash

# Script to deploy only the payment service without recreating existing infrastructure
set -e

echo "🚀 Deploying payment service..."

# Navigate to terraform/eks-deployment directory
cd terraform/eks-deployment

# Initialize Terraform
echo "📝 Initializing Terraform..."
docker run --rm -it \
  -v $(pwd):/workspace \
  -v ~/.aws:/root/.aws \
  -w /workspace \
  hashicorp/terraform:latest init

# Plan Terraform configuration - only target the payment service resources
echo "📋 Planning Terraform configuration..."
docker run --rm -it \
  -v $(pwd):/workspace \
  -v ~/.aws:/root/.aws \
  -w /workspace \
  hashicorp/terraform:latest plan \
  -target=module.eks_payment_service.kubernetes_namespace.payment_service \
  -target=module.eks_payment_service.kubernetes_config_map.payment_service_config \
  -target=module.eks_payment_service.kubernetes_deployment.payment_service \
  -target=module.eks_payment_service.kubernetes_service.payment_service \
  -target=module.eks_payment_service.kubernetes_horizontal_pod_autoscaler_v2.payment_service_hpa \
  -var-file=terraform.tfvars \
  -out=payment-service.tfplan

# Apply Terraform configuration
echo "🔧 Applying Terraform configuration..."
docker run --rm -it \
  -v $(pwd):/workspace \
  -v ~/.aws:/root/.aws \
  -w /workspace \
  hashicorp/terraform:latest apply payment-service.tfplan

echo "✅ Deployment completed!"
echo ""
echo "To check the payment service, run:"
echo "kubectl get pods -n payment-service"
echo ""