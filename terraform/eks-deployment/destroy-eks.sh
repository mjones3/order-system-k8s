#!/bin/bash

# EKS Cleanup Script for Order System
set -e

echo "🧹 Starting EKS cleanup for Order System..."

# Check if terraform state exists
if [ ! -f "terraform.tfstate" ]; then
    echo "❌ No terraform state found. Nothing to destroy."
    exit 1
fi

echo "⚠️  This will destroy ALL resources including:"
echo "   - EKS Cluster"
echo "   - RDS Databases"
echo "   - VPC and networking"
echo "   - All deployed services"
echo ""
echo "Are you sure you want to continue? (y/N)"
read -r response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "❌ Cleanup cancelled"
    exit 1
fi

# Destroy services first
echo "🗑️  Destroying services..."
terraform destroy -var-file="terraform.tfvars" \
    -target=module.eks_order_service \
    -target=module.eks_inventory_service \
    -target=module.eks_payment_service \
    -auto-approve

# Destroy infrastructure
echo "🗑️  Destroying infrastructure..."
terraform destroy -var-file="terraform.tfvars" \
    -auto-approve

echo "✅ EKS cleanup completed successfully!"