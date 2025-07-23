#!/bin/bash

# Script to deploy the payment service with both Terraform and Kubernetes resources
set -e

REGION="us-east-1"
ENVIRONMENT=${ENVIRONMENT:-"cloud"}
SKIP_IMPORT=${SKIP_IMPORT:-"false"}
SKIP_TERRAFORM=${SKIP_TERRAFORM:-"false"}
SKIP_KUBERNETES=${SKIP_KUBERNETES:-"false"}
DB_HOST=${DB_HOST:-""}
DB_PORT=${DB_PORT:-"5432"}
DB_NAME=${DB_NAME:-"paymentdb"}
DB_USER=${DB_USER:-"paymentuser"}
DB_PASSWORD=${DB_PASSWORD:-"password123"}
IMAGE_TAG=${IMAGE_TAG:-"latest"}

echo "🚀 Deploying payment service (Environment: ${ENVIRONMENT})"

# Step 1: Deploy with Terraform if not skipped
if [ "$SKIP_TERRAFORM" != "true" ]; then
  echo "📝 Running Terraform deployment..."
  ./deploy-payment-service-tf.sh
  
  # Get the RDS endpoint if not provided
  if [ -z "$DB_HOST" ]; then
    echo "🔍 Getting RDS endpoint from Terraform outputs..."
    DB_HOST=$(docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace hashicorp/terraform:latest output -json module.payment_service_db | jq -r '.rds_endpoint.value' | cut -d':' -f1)
    echo "Using RDS endpoint: $DB_HOST"
  fi
else
  echo "⏩ Skipping Terraform deployment as requested"
fi

# Step 2: Deploy Kubernetes resources if not skipped
if [ "$SKIP_KUBERNETES" != "true" ]; then
  echo "📝 Running Kubernetes deployment..."
  
  # Set the database host if it was retrieved from Terraform
  if [ -n "$DB_HOST" ]; then
    export DB_HOST="$DB_HOST"
  fi
  
  ./deploy-payment-service.sh
else
  echo "⏩ Skipping Kubernetes deployment as requested"
fi

echo "✅ Payment service deployment completed."
echo "To check the service endpoint, run:"
echo "kubectl get ingress payment-service-ingress -n payment-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"