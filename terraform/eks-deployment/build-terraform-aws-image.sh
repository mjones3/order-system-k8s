#!/bin/bash

# Script to build a custom Docker image with Terraform, AWS CLI, and kubectl
set -e

echo "🔨 Building custom Terraform AWS Docker image..."
docker build -t terraform-aws-kubectl -f Dockerfile.terraform-aws .

echo "✅ Image built successfully!"
echo "You can now use this image for Terraform operations:"
echo "docker run --rm -v \$(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace terraform-aws-kubectl init"