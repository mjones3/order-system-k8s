#!/bin/bash

echo "🔧 Quick fix for provider timeout issues..."

# Kill any stuck processes
echo "1. Killing stuck terraform processes..."
pkill -f terraform 2>/dev/null || true
pkill -f terraform-provider 2>/dev/null || true

# Clean terraform state
echo "2. Cleaning terraform state..."
rm -rf .terraform/
rm -f .terraform.lock.hcl
rm -f *.tfplan
rm -f terraform-verbose.log

# Reduce memory pressure
echo "3. Reducing system load..."
echo "💡 Close other applications to free memory (currently at 72.5%)"

# Reinitialize with minimal logging
echo "4. Reinitializing terraform..."
export TF_LOG=WARN  # Reduce logging
unset TF_LOG_PATH   # Don't write debug logs to file
terraform init

echo "5. Testing simple plan..."
terraform plan -var-file=terraform.tfvars -compact-warnings

echo "✅ If this works, you can now run terraform apply"