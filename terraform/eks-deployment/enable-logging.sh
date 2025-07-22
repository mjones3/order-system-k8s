#!/bin/bash

# Enable Terraform logging for current session
echo "🔧 Enabling Terraform logging..."

# Set environment variables for detailed logging
export TF_LOG=DEBUG
export TF_LOG_PATH=./terraform-debug.log

echo "✅ Terraform logging enabled!"
echo "📋 Debug logs will be written to: terraform-debug.log"
echo "📋 You can monitor in real-time with: tail -f terraform-debug.log"
echo ""
echo "🚀 Now run your terraform commands and they will be logged"
echo "Example: terraform plan -var-file=terraform.tfvars"
echo "Example: terraform apply -var-file=terraform.tfvars"