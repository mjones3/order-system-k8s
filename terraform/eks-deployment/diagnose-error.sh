#!/bin/bash

echo "🔍 Diagnosing Terraform deployment errors..."

# Check if terraform.tfvars exists
echo "1. Checking terraform.tfvars..."
if [ -f "terraform.tfvars" ]; then
    echo "✅ terraform.tfvars exists"
else
    echo "❌ terraform.tfvars missing"
    exit 1
fi

# Check AWS credentials
echo ""
echo "2. Checking AWS credentials..."
aws sts get-caller-identity >/dev/null 2>&1 && echo "✅ AWS credentials valid" || echo "❌ AWS credentials issue"

# Check terraform validation
echo ""
echo "3. Checking Terraform configuration..."
terraform validate >/dev/null 2>&1 && echo "✅ Terraform config valid" || echo "❌ Terraform config invalid"

# Try a simple terraform plan with minimal output
echo ""
echo "4. Testing terraform plan (this may take a moment)..."
export TF_LOG=ERROR
terraform plan -var-file=terraform.tfvars -out=test.tfplan 2>&1 | head -20

# Check if plan succeeded
if [ -f "test.tfplan" ]; then
    echo "✅ Terraform plan succeeded"
    rm -f test.tfplan
else
    echo "❌ Terraform plan failed"
    echo ""
    echo "Recent errors from logs:"
    grep -i "error\|failed\|timeout" terraform-verbose.log 2>/dev/null | tail -5 || echo "No specific errors found in logs"
fi

# Check system resources
echo ""
echo "5. System resources:"
echo "Memory usage: $(ps -A -o %mem | awk '{s+=$1} END {print s "%"}')"
echo "Running terraform processes: $(ps aux | grep terraform | grep -v grep | wc -l)"

echo ""
echo "💡 If plan failed, try:"
echo "   - ./kill-stuck-terraform.sh"
echo "   - rm -rf .terraform/ && terraform init"
echo "   - terraform plan -var-file=terraform.tfvars"