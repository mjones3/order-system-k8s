#!/bin/bash

# Script to test Terraform configuration using Docker
set -e

WORKDIR="/workspace"
CURRENT_DIR=$(pwd)

echo "🔍 Testing Terraform configuration..."

# Initialize Terraform
echo "📝 Initializing Terraform..."
docker run --rm -v ${CURRENT_DIR}:/workspace \
  -v ~/.aws:/root/.aws \
  -w ${WORKDIR}/terraform/eks-deployment \
  hashicorp/terraform:latest init -reconfigure

# Validate Terraform configuration
echo "✅ Validating Terraform configuration..."
docker run --rm -v ${CURRENT_DIR}:/workspace \
  -v ~/.aws:/root/.aws \
  -w ${WORKDIR}/terraform/eks-deployment \
  hashicorp/terraform:latest validate

echo "✅ Terraform configuration is valid!"