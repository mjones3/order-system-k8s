#!/bin/bash

# EKS Deployment Script for Order System using Docker
set -e

echo "🚀 Starting EKS deployment for Order System using Docker..."

# Check if required files exist
if [ ! -f "terraform.tfvars" ]; then
    echo "❌ terraform.tfvars file not found!"
    echo "Please copy terraform.tfvars.example to terraform.tfvars and update with your values"
    exit 1
fi

# Set Docker image
TERRAFORM_IMAGE="hashicorp/terraform:1.7.5"

# Initialize Terraform
echo "📦 Initializing Terraform..."
docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace \
    -e AWS_PROFILE=${AWS_PROFILE:-default} \
    -e TF_PLUGIN_TIMEOUT=300 \
    -e AWS_MAX_ATTEMPTS=10 \
    -e AWS_RETRY_MODE=adaptive \
    ${TERRAFORM_IMAGE} init

# Validate the configuration
echo "🔍 Validating Terraform configuration..."
docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace \
    -e AWS_PROFILE=${AWS_PROFILE:-default} \
    ${TERRAFORM_IMAGE} validate

# Plan the deployment
echo "📋 Planning Terraform deployment..."
docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace \
    -e AWS_PROFILE=${AWS_PROFILE:-default} \
    -e TF_LOG=INFO \
    -e TF_PLUGIN_TIMEOUT=300 \
    ${TERRAFORM_IMAGE} plan -var-file="terraform.tfvars" \
    -out=eks-plan.tfplan \
    -target=module.network \
    -target=module.eks \
    -target=module.order_service_db \
    -target=module.inventory_service_db \
    -target=module.payment_service_db

echo "🔍 Review the plan above. Do you want to continue? (y/N)"
read -r response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "❌ Deployment cancelled"
    exit 1
fi

# Apply infrastructure (VPC, EKS, RDS)
echo "🏗️  Applying infrastructure..."
docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace \
    -e AWS_PROFILE=${AWS_PROFILE:-default} \
    -e TF_LOG=INFO \
    ${TERRAFORM_IMAGE} apply eks-plan.tfplan

# Wait for EKS cluster to be ready
echo "⏳ Waiting for EKS cluster to be ready..."
aws eks wait cluster-active --name order-system-cluster --region us-east-1

# Update kubeconfig
echo "🔧 Updating kubeconfig..."
aws eks update-kubeconfig --name order-system-cluster --region us-east-1

# Plan and apply services
echo "📋 Planning service deployments..."
docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace \
    -e AWS_PROFILE=${AWS_PROFILE:-default} \
    ${TERRAFORM_IMAGE} plan -var-file="terraform.tfvars" \
    -out=services-plan.tfplan \
    -target=module.eks_order_service \
    -target=module.eks_inventory_service \
    -target=module.eks_payment_service

echo "🚀 Deploying services to EKS..."
docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace \
    -e AWS_PROFILE=${AWS_PROFILE:-default} \
    ${TERRAFORM_IMAGE} apply services-plan.tfplan

# Verify deployments
echo "✅ Verifying deployments..."
kubectl get namespaces
kubectl get deployments --all-namespaces
kubectl get services --all-namespaces

echo "🎉 EKS deployment completed successfully!"
echo ""
echo "📊 Cluster Information:"
docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace \
    -e AWS_PROFILE=${AWS_PROFILE:-default} \
    ${TERRAFORM_IMAGE} output cluster_endpoint
echo ""
echo "🔗 Service Endpoints:"
docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace \
    -e AWS_PROFILE=${AWS_PROFILE:-default} \
    ${TERRAFORM_IMAGE} output order_service_endpoint
docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace \
    -e AWS_PROFILE=${AWS_PROFILE:-default} \
    ${TERRAFORM_IMAGE} output inventory_service_endpoint
docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace \
    -e AWS_PROFILE=${AWS_PROFILE:-default} \
    ${TERRAFORM_IMAGE} output payment_service_endpoint
echo ""
echo "💡 To access your services:"
echo "   kubectl get services --all-namespaces"
echo "   kubectl port-forward -n <namespace> service/<service-name> 8080:80"