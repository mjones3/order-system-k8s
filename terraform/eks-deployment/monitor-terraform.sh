#!/bin/bash

echo "🔍 Monitoring Terraform activity..."

# Check if terraform is running
TERRAFORM_PIDS=$(pgrep -f terraform || echo "")
if [ -n "$TERRAFORM_PIDS" ]; then
    echo "✅ Terraform processes found:"
    ps aux | grep terraform | grep -v grep
    echo ""
else
    echo "❌ No terraform processes running"
fi

# Check for terraform lock files
echo "🔒 Terraform Lock Status:"
if [ -f ".terraform.tfstate.lock.info" ]; then
    echo "🔒 Terraform is locked (operation in progress)"
    echo "Lock info:"
    cat .terraform.tfstate.lock.info | jq . 2>/dev/null || cat .terraform.tfstate.lock.info
else
    echo "🔓 No terraform lock found"
fi

# Check terraform state
echo ""
echo "📊 Terraform State:"
if [ -f "terraform.tfstate" ]; then
    echo "State file exists, checking resources..."
    terraform show -json 2>/dev/null | jq -r '.values.root_module.resources[]?.address // empty' 2>/dev/null | head -10 || echo "Could not parse state"
else
    echo "No terraform.tfstate file found"
fi

# Check for any terraform log files
echo ""
echo "📋 Available Log Files:"
ls -la *.log 2>/dev/null || echo "No log files found"

# Check AWS CloudTrail for recent API calls (if you want to see what's happening in AWS)
echo ""
echo "☁️  Recent AWS API Activity (last 10 minutes):"
aws logs describe-log-groups --log-group-name-prefix "/aws/eks" --query 'logGroups[].logGroupName' --output table 2>/dev/null || echo "No EKS logs found yet"