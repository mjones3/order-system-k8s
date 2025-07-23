#!/bin/bash

# Script to test the Step Functions and API Gateway
set -e

REGION="us-east-1"

echo "🧪 Testing Step Functions and API Gateway..."

# Get the API Gateway endpoint
echo "🔍 Getting API Gateway endpoint..."
cd terraform/eks-deployment
API_ENDPOINT=$(docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace -e AWS_REGION=${REGION} hashicorp/terraform:latest output -json module.api-sfn | jq -r '.api_endpoint.value')
cd ../..

if [ -z "$API_ENDPOINT" ]; then
  echo "❌ Failed to get API Gateway endpoint. Make sure the API Gateway is deployed."
  exit 1
fi

echo "API Gateway endpoint: ${API_ENDPOINT}"

# Test the API Gateway
echo "🔍 Testing API Gateway..."
curl -X POST "${API_ENDPOINT}/order" \
  -H "Content-Type: application/json" \
  -d '{
    "orderId": "123",
    "customerId": "456",
    "items": [
      {
        "productId": "789",
        "quantity": 1
      }
    ]
  }'

echo ""
echo "✅ Test completed. Check the AWS Step Functions console to see the execution."
echo "https://console.aws.amazon.com/states/home?region=${REGION}#/statemachines"