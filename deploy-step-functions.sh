#!/bin/bash

# Script to deploy the Step Functions and API Gateway using Docker Terraform
set -e

TERRAFORM_IMAGE="hashicorp/terraform:latest"
REGION="us-east-1"

echo "🚀 Deploying Step Functions and API Gateway..."

# Navigate to the Terraform directory
cd terraform/eks-deployment

# Function to run Terraform commands via Docker
run_terraform() {
  docker run --rm -it \
    -v $(pwd):/workspace \
    -v ~/.aws:/root/.aws \
    -w /workspace \
    -e AWS_REGION=${REGION} \
    ${TERRAFORM_IMAGE} $@
}

# Initialize Terraform
echo "📝 Initializing Terraform..."
run_terraform init

# Create a plan file for the lambda and api-sfn modules
echo "📋 Creating plan for lambda and api-sfn modules..."
run_terraform plan \
  -target=module.lambda \
  -target=module.api-sfn \
  -out=step-functions.tfplan

# Apply the plan automatically
echo "🔧 Applying Step Functions and API Gateway..."
run_terraform apply -auto-approve step-functions.tfplan

# Get the API Gateway endpoint
echo "🔍 Getting API Gateway endpoint..."
API_ENDPOINT=$(run_terraform output -json module.api-sfn | jq -r '.api_endpoint.value')

echo "✅ Step Functions and API Gateway deployed successfully."
echo "API Gateway endpoint: ${API_ENDPOINT}"
echo ""
echo "To test the API, you can use the following curl command:"
echo "curl -X POST ${API_ENDPOINT}/order -H 'Content-Type: application/json' -d '{\"orderId\": \"123\", \"customerId\": \"456\", \"items\": [{\"productId\": \"789\", \"quantity\": 1}]}'"