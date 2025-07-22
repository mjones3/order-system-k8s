#!/bin/bash

# EKS Deployment Script for Order System (Verbose Version)
set -e

echo "🚀 Starting EKS deployment for Order System..."

# Enable verbose Terraform logging
export TF_LOG=DEBUG
export TF_LOG_PATH=./terraform.log
export TF_PLUGIN_TIMEOUT=600s  # 10 minutes for EKS operations

# Check if required files exist
if [ ! -f "terraform.tfvars" ]; then
    echo "❌ terraform.tfvars file not found!"
    echo "Please copy terraform.tfvars.example to terraform.tfvars and update with your values"
    exit 1
fi

# Initialize Terraform
echo "📦 Initializing Terraform..."
terraform init

# Plan the deployment
echo "📋 Planning Terraform deployment..."
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

# Apply infrastructure (VPC, EKS, RDS) with progress monitoring
echo "🏗️  Applying infrastructure..."
echo "📊 This will take 10-15 minutes. Progress will be logged to terraform.log"
echo "💡 You can monitor progress in another terminal with: tail -f terraform.log"
echo ""

# Start background monitoring
(
    while true; do
        if [ -f terraform.log ]; then
            # Show EKS cluster creation progress
            if grep -q "aws_eks_cluster.this" terraform.log 2>/dev/null; then
                echo "⏳ EKS cluster creation in progress..."
            fi
            # Show RDS creation progress
            if grep -q "aws_db_instance" terraform.log 2>/dev/null; then
                echo "🗄️  RDS database creation in progress..."
            fi
            # Show VPC creation progress
            if grep -q "aws_vpc" terraform.log 2>/dev/null; then
                echo "🌐 VPC creation in progress..."
            fi
        fi
        sleep 30
    done
) &
MONITOR_PID=$!

# Apply with timeout and progress
timeout 1800 terraform apply eks-plan.tfplan || {
    echo "❌ Terraform apply timed out after 30 minutes"
    kill $MONITOR_PID 2>/dev/null || true
    exit 1
}

# Stop monitoring
kill $MONITOR_PID 2>/dev/null || true

# Wait for EKS cluster to be ready
echo "⏳ Waiting for EKS cluster to be ready..."
aws eks wait cluster-active --name order-system-cluster --region us-east-1 || {
    echo "❌ EKS cluster failed to become active"
    exit 1
}

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
echo ""
echo "📋 Logs saved to: terraform.log"