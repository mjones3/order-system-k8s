#!/bin/bash

# EKS Deployment Script for Order System
set -e

echo "🚀 Starting EKS deployment for Order System..."

# Check if required files exist
if [ ! -f "terraform.tfvars" ]; then
    echo "❌ terraform.tfvars file not found!"
    echo "Please copy terraform.tfvars.example to terraform.tfvars and update with your values"
    exit 1
fi

# Initialize Terraform
echo "📦 Initializing Terraform..."
export TF_PLUGIN_TIMEOUT=300
export AWS_MAX_ATTEMPTS=10
export AWS_RETRY_MODE=adaptive
terraform init

# Plan the deployment
echo "📋 Planning Terraform deployment..."
export TF_LOG=INFO
export TF_PLUGIN_TIMEOUT=300
terraform plan -var-file="terraform.tfvars" \
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
export TF_LOG=INFO
terraform apply eks-plan.tfplan

# Wait for EKS cluster to be ready
echo "⏳ Waiting for EKS cluster to be ready..."
aws eks wait cluster-active --name order-system-cluster --region us-east-1

# Update kubeconfig
echo "🔧 Updating kubeconfig..."
aws eks update-kubeconfig --name order-system-cluster --region us-east-1

# Plan and apply services
echo "📋 Planning service deployments..."
terraform plan -var-file="terraform.tfvars" \
    -out=services-plan.tfplan \
    -target=module.eks_order_service \
    -target=module.eks_inventory_service \
    -target=module.eks_payment_service

echo "🚀 Deploying services to EKS..."
terraform apply services-plan.tfplan

# Verify deployments
echo "✅ Verifying deployments..."
kubectl get namespaces
kubectl get deployments --all-namespaces
kubectl get services --all-namespaces

echo "🎉 EKS deployment completed successfully!"
echo ""
echo "📊 Cluster Information:"
terraform output cluster_endpoint
echo ""
echo "🔗 Service Endpoints:"
terraform output order_service_endpoint
terraform output inventory_service_endpoint
terraform output payment_service_endpoint
echo ""
echo "💡 To access your services:"
echo "   kubectl get services --all-namespaces"
echo "   kubectl port-forward -n <namespace> service/<service-name> 8080:80"