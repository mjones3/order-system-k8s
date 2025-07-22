#!/bin/bash

# Script to deploy the order service with ALB ingress using a custom Docker image
set -e

# Working directory
WORKDIR="/workspace/terraform/eks-deployment"
CURRENT_DIR=$(pwd)

echo "🚀 Deploying order service with ALB ingress..."

# Build the custom Docker image
echo "🔨 Building custom Terraform AWS Docker image..."
cd terraform/eks-deployment
docker build -t terraform-aws-kubectl -f Dockerfile.terraform-aws .
cd -

# Initialize Terraform
echo "📝 Initializing Terraform..."
docker run --rm -v $CURRENT_DIR:/workspace \
  -v ~/.aws:/root/.aws \
  -w $WORKDIR \
  terraform-aws-kubectl init

# Plan Terraform changes
echo "📋 Planning Terraform changes..."
docker run --rm -v $CURRENT_DIR:/workspace \
  -v ~/.aws:/root/.aws \
  -w $WORKDIR \
  terraform-aws-kubectl plan \
  -target=module.eks_order_service.kubernetes_ingress_v1.order_service_ingress \
  -out=ingress.tfplan

# Apply Terraform changes
echo "🔧 Applying Terraform changes..."
docker run --rm -v $CURRENT_DIR:/workspace \
  -v ~/.aws:/root/.aws \
  -w $WORKDIR \
  terraform-aws-kubectl apply ingress.tfplan

# Wait for the ingress to be provisioned
echo "⏳ Waiting for ALB ingress to be provisioned (this may take a few minutes)..."
sleep 30

# Get the ingress hostname
INGRESS_HOSTNAME=$(docker run --rm -v $CURRENT_DIR:/workspace \
  -v ~/.aws:/root/.aws \
  -w $WORKDIR \
  terraform-aws-kubectl output -raw order_service_ingress_hostname 2>/dev/null || echo "")

if [ -z "$INGRESS_HOSTNAME" ]; then
  echo "⚠️ Ingress hostname not available yet. It may take a few minutes for the ALB to be provisioned."
  echo "Run the following command to check the status:"
  echo "kubectl get ingress -n order-service"
  echo "Once the ingress is provisioned, you can get the URL with:"
  echo "docker run --rm -v \$(pwd):/workspace -v ~/.aws:/root/.aws -w $WORKDIR terraform-aws-kubectl output order_service_url"
else
  echo "✅ Order service is now accessible at: http://$INGRESS_HOSTNAME"
  echo "You can make API requests to this endpoint, for example:"
  echo "curl -X GET http://$INGRESS_HOSTNAME/actuator/health"
fi