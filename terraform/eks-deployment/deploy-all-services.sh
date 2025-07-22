#!/bin/bash

# Script to deploy all services
set -e

CLUSTER_NAME="order-system-cluster"
REGION="us-east-1"

echo "🚀 Deploying all services to EKS cluster: ${CLUSTER_NAME}"

# Update kubeconfig
echo "📝 Updating kubeconfig..."
aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${REGION}

# Apply all service modules
echo "🔧 Applying all service modules..."
docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace hashicorp/terraform:latest apply \
  -target=module.eks_order_service \
  -target=module.eks_inventory_service \
  -target=module.eks_payment_service

# Wait for deployments to be ready
echo "⏳ Waiting for order service deployment to be ready..."
kubectl rollout status deployment/order-service -n order-service --timeout=300s || true

echo "⏳ Waiting for inventory service deployment to be ready..."
kubectl rollout status deployment/inventory-service -n inventory-service --timeout=300s || true

echo "⏳ Waiting for payment service deployment to be ready..."
kubectl rollout status deployment/payment-service -n payment-service --timeout=300s || true

# Check services
echo "🔍 Checking services..."
kubectl get services --all-namespaces | grep -E 'order-service|inventory-service|payment-service'

# Check pods
echo "🔍 Checking pods..."
kubectl get pods --all-namespaces | grep -E 'order-service|inventory-service|payment-service'

echo "✅ All services deployment completed."