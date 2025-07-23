#!/bin/bash

# Script to update the inventory service ConfigMap with the new password
set -e

echo "🚀 Updating inventory service ConfigMap..."

# Update the ConfigMap
echo "📝 Updating ConfigMap..."
kubectl apply -f inventory-service-config-update.yaml

# Restart the inventory service deployment
echo "🔄 Restarting inventory service deployment..."
kubectl rollout restart deployment inventory-service -n inventory-service

# Wait for the deployment to be ready
echo "⏳ Waiting for deployment to be ready..."
kubectl rollout status deployment/inventory-service -n inventory-service --timeout=300s

# Check pods
echo "🔍 Checking inventory service pods..."
kubectl get pods -n inventory-service -l app=inventory-service

echo "✅ Inventory service ConfigMap update completed."