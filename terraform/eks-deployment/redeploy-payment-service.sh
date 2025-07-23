#!/bin/bash

# Script to redeploy the payment service with the correct password
set -e

REGION="us-east-1"
ENVIRONMENT=${ENVIRONMENT:-"cloud"}
DB_PASSWORD="password123"

echo "🚀 Redeploying payment service with correct password (Environment: ${ENVIRONMENT})"

# Step 1: Update the database password
echo "📝 Updating database password..."
./update-payment-db-password.sh

# Step 2: Delete the existing deployment and related resources
echo "🗑️ Deleting existing payment service resources..."
kubectl delete deployment payment-service -n payment-service --ignore-not-found=true
kubectl delete configmap payment-service-config -n payment-service --ignore-not-found=true

# Step 3: Deploy the payment service with the correct password
echo "🔄 Redeploying payment service..."
DB_PASSWORD=${DB_PASSWORD} ./deploy-payment-service-k8s-only.sh

echo "✅ Payment service redeployment completed."
echo "To check the service endpoint, run:"
echo "kubectl get ingress payment-service-ingress -n payment-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
echo "To check the logs, run:"
echo "kubectl logs -n payment-service -l app=payment-service"