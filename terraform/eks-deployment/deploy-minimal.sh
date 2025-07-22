#!/bin/bash

echo "🚀 Minimal EKS deployment (reduced resource usage)..."

# Clean start
rm -rf .terraform/
rm -f *.tfplan *.log

# Minimal environment
export TF_LOG=WARN
unset TF_LOG_PATH
export TF_PLUGIN_TIMEOUT=300

echo "📦 Initializing..."
terraform init || exit 1

echo "📋 Planning infrastructure only (no services)..."
terraform plan \
    -var-file=terraform.tfvars \
    -target=module.network \
    -target=module.eks \
    -out=infra.tfplan

echo "🔍 Review the plan. Continue? (y/N)"
read -r response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    exit 1
fi

echo "🏗️  Applying infrastructure..."
terraform apply infra.tfplan

echo "✅ Infrastructure deployed! Services can be added later."