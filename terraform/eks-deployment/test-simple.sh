#!/bin/bash

echo "🧪 Testing simple Terraform configuration..."

# Clean start
rm -rf .terraform/
rm -f *.tfplan

# Use simple config
mv main.tf main-complex.tf 2>/dev/null || true
mv variables.tf variables-complex.tf 2>/dev/null || true
mv main-simple.tf main.tf
mv variables-simple.tf variables.tf

# Test
echo "📦 Initializing..."
terraform init

echo "📋 Planning..."
terraform plan

echo "✅ If this works, the issue is configuration complexity"
echo "💡 Revert with: mv main-complex.tf main.tf && mv variables-complex.tf variables.tf"