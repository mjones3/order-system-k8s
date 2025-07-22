#!/bin/bash

echo "🛠️  Cleaning up stuck Terraform deployment..."

# Check for lock file
if [ -f ".terraform.tfstate.lock.info" ]; then
    echo "🔒 Found terraform lock file"
    echo "Lock info:"
    cat .terraform.tfstate.lock.info
    echo ""
    echo "To remove lock, run: terraform force-unlock <LOCK_ID>"
    LOCK_ID=$(cat .terraform.tfstate.lock.info | grep '"ID"' | cut -d'"' -f4)
    if [ -n "$LOCK_ID" ]; then
        echo "Detected Lock ID: $LOCK_ID"
        echo "Run: terraform force-unlock $LOCK_ID"
    fi
else
    echo "✅ No terraform lock found"
fi

# Check what resources exist
echo ""
echo "📊 Checking existing resources..."
terraform show 2>/dev/null | head -20 || echo "No resources found or state file issue"

# Check AWS resources that might have been created
echo ""
echo "☁️  Checking AWS resources..."
echo "VPCs:"
aws ec2 describe-vpcs --filters "Name=tag:project,Values=order-system" --query 'Vpcs[].{VpcId:VpcId,State:State}' --output table 2>/dev/null || echo "No VPCs found"

echo ""
echo "EKS Clusters:"
aws eks list-clusters --query 'clusters' --output table 2>/dev/null || echo "No EKS clusters found"

echo ""
echo "RDS Instances:"
aws rds describe-db-instances --query 'DBInstances[?contains(DBInstanceIdentifier, `order`)].{Name:DBInstanceIdentifier,Status:DBInstanceStatus}' --output table 2>/dev/null || echo "No RDS instances found"

echo ""
echo "💡 Next steps:"
echo "1. If locked: terraform force-unlock <LOCK_ID>"
echo "2. Check what was created: terraform show"
echo "3. Continue deployment: terraform apply"
echo "4. Or destroy partial resources: terraform destroy"