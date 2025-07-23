#!/bin/bash

# Script to deploy all services (order, inventory, payment, and step functions)
set -e

REGION="us-east-1"
ENVIRONMENT=${ENVIRONMENT:-"cloud"}
SKIP_ORDER=${SKIP_ORDER:-"false"}
SKIP_INVENTORY=${SKIP_INVENTORY:-"false"}
SKIP_PAYMENT=${SKIP_PAYMENT:-"false"}
SKIP_STEP_FUNCTIONS=${SKIP_STEP_FUNCTIONS:-"false"}

echo "🚀 Deploying all services (Environment: ${ENVIRONMENT})"

# Deploy order service
if [ "$SKIP_ORDER" != "true" ]; then
  echo "📦 Deploying order service..."
  cd terraform/eks-deployment
  ./deploy-order-service-tf.sh
  cd ../..
  ./terraform/eks-deployment/deploy-order-service.sh
  echo "✅ Order service deployment completed."
else
  echo "⏩ Skipping order service deployment."
fi

# Deploy inventory service
if [ "$SKIP_INVENTORY" != "true" ]; then
  echo "📦 Deploying inventory service..."
  cd terraform/eks-deployment
  ./deploy-inventory-service-tf.sh
  cd ../..
  # Assuming you have a deploy-inventory-service.sh script
  # ./terraform/eks-deployment/deploy-inventory-service.sh
  echo "✅ Inventory service deployment completed."
else
  echo "⏩ Skipping inventory service deployment."
fi

# Deploy payment service
if [ "$SKIP_PAYMENT" != "true" ]; then
  echo "📦 Deploying payment service..."
  cd terraform/eks-deployment
  ./deploy-payment-service-tf.sh
  cd ../..
  ./terraform/eks-deployment/deploy-payment-service.sh
  echo "✅ Payment service deployment completed."
else
  echo "⏩ Skipping payment service deployment."
fi

# Deploy step functions
if [ "$SKIP_STEP_FUNCTIONS" != "true" ]; then
  echo "📦 Deploying step functions..."
  ./deploy-step-functions-complete.sh
  echo "✅ Step functions deployment completed."
else
  echo "⏩ Skipping step functions deployment."
fi

echo "🎉 All services deployed successfully!"
echo ""
echo "To test the API, you can use the following curl command:"
echo "curl -X POST \$(aws apigatewayv2 get-apis --query \"Items[?Name=='orders-saga-api'].ApiEndpoint\" --output text)/order -H 'Content-Type: application/json' -d '{\"orderId\": \"123\", \"customerId\": \"456\", \"items\": [{\"productId\": \"789\", \"quantity\": 1}]}'"