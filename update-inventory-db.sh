#!/bin/bash

# Script to update the inventory service database password
set -e

echo "🚀 Updating inventory service database password..."

# Navigate to terraform/eks-deployment directory
cd terraform/eks-deployment

# Update the RDS instance password
echo "📝 Updating RDS instance password..."
docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace hashicorp/terraform:latest apply \
  -target=module.inventory_service_db \
  -var-file=inventory-db-update.tfvars \
  -auto-approve

# Wait for the RDS instance to be updated
echo "⏳ Waiting for RDS instance to be updated..."
sleep 30

# Update the ConfigMap
echo "📝 Updating ConfigMap..."
kubectl apply -f ../inventory-service-config-update.yaml

# Restart the inventory service deployment
echo "🔄 Restarting inventory service deployment..."
kubectl rollout restart deployment inventory-service -n inventory-service

# Wait for the deployment to be ready
echo "⏳ Waiting for deployment to be ready..."
kubectl rollout status deployment/inventory-service -n inventory-service --timeout=300s

# Check pods
echo "🔍 Checking inventory service pods..."
kubectl get pods -n inventory-service -l app=inventory-service

echo "✅ Inventory service database password update completed."