#!/bin/bash

# Script to fix the VPC configuration to use existing VPC and subnets
set -e

echo "🔧 Fixing VPC configuration to use existing VPC and subnets..."

# Create a backup of the current state
echo "📦 Creating backup of current state..."
cp terraform.tfstate terraform.tfstate.bak.$(date +%Y%m%d%H%M%S)

# Remove the problematic resources from the state
echo "🗑️ Removing problematic resources from state..."
docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace hashicorp/terraform:latest state rm module.network.aws_vpc.this
docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace hashicorp/terraform:latest state rm module.network.aws_subnet.public
docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace hashicorp/terraform:latest state rm module.network.aws_subnet.private
docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace hashicorp/terraform:latest state rm module.network.aws_subnet.db
docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace hashicorp/terraform:latest state rm module.network.aws_db_subnet_group.order_db_subnet_group
docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace hashicorp/terraform:latest state rm module.network.aws_db_subnet_group.inventory_db_subnet_group

# Import the existing resources
echo "📥 Importing existing VPC..."
docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace hashicorp/terraform:latest import module.network.data.aws_vpc.existing vpc-024c0c2f1ea047c09

echo "📥 Importing existing DB subnet group..."
docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace hashicorp/terraform:latest import module.network.data.aws_db_subnet_group.db_subnet_group order-system-db-subnet-group

# Run plan to see what changes would be made
echo "📋 Running plan to see what changes would be made..."
docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace hashicorp/terraform:latest plan -var-file=terraform.tfvars -out=eks-fixed.tfplan

echo "✅ VPC configuration fixed! Review the plan above and apply with:"
echo "docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace hashicorp/terraform:latest apply eks-fixed.tfplan"