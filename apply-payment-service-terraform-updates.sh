#!/bin/bash

# Script to apply the payment service Terraform updates
set -e

TERRAFORM_IMAGE="hashicorp/terraform:latest"

echo "🚀 Applying payment service Terraform updates..."

# Navigate to the Terraform directory
cd terraform/eks-deployment

# Function to run Terraform commands via Docker
run_terraform() {
  docker run --rm -it \
    -v $(pwd):/workspace \
    -v ~/.aws:/root/.aws \
    -w /workspace \
    ${TERRAFORM_IMAGE} $@
}

# Initialize Terraform
echo "📝 Initializing Terraform..."
run_terraform init

# Create a plan file for the payment service modules
echo "📋 Creating plan for payment service modules..."
run_terraform plan \
  -target=module.payment_service_db \
  -target=module.eks_payment_service \
  -out=payment-service-updates.tfplan

# Apply the plan automatically
echo "🔧 Applying payment service updates..."
run_terraform apply -auto-approve payment-service-updates.tfplan

echo "✅ Payment service Terraform updates applied successfully."