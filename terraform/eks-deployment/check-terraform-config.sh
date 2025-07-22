#!/bin/bash
set -e

# Working directory
WORKDIR="/workspace"
CURRENT_DIR=$(pwd)

echo "🔍 Checking Terraform configuration..."

# Initialize Terraform
echo "📝 Initializing Terraform..."
docker run --rm -v ${CURRENT_DIR}:/workspace \
  -v ~/.aws:/root/.aws \
  -w ${WORKDIR}/terraform/eks-deployment \
  hashicorp/terraform:latest init -reconfigure

# Validate Terraform configuration
echo "🔍 Validating Terraform configuration..."
docker run --rm -v ${CURRENT_DIR}:/workspace \
  -v ~/.aws:/root/.aws \
  -w ${WORKDIR}/terraform/eks-deployment \
  hashicorp/terraform:latest validate

echo "✅ Terraform configuration is valid."