#!/bin/bash

echo "🔧 Fixing all Terraform deployment errors..."

# 1. Clean up failed RDS resources
echo "1. Cleaning up RDS conflicts..."
OLD_INSTANCES=$(aws rds describe-db-instances --query 'DBInstances[?contains(DBInstanceIdentifier, `terraform-2025`)].DBInstanceIdentifier' --output text)

if [ -n "$OLD_INSTANCES" ]; then
    echo "Deleting old RDS instances..."
    for instance in $OLD_INSTANCES; do
        aws rds delete-db-instance --db-instance-identifier "$instance" --skip-final-snapshot --delete-automated-backups --no-cli-pager
    done
    echo "⏳ Waiting for RDS instances to delete..."
    sleep 30
fi

# 2. Remove failed EKS node group
echo "2. Cleaning up failed EKS node group..."
aws eks delete-nodegroup --cluster-name order-system-cluster --nodegroup-name main-20250721124512463300000001 --no-cli-pager 2>/dev/null || echo "Node group already deleted or doesn't exist"

# 3. Clean up tainted resources in Terraform state
echo "3. Cleaning up Terraform state..."
docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace hashicorp/terraform:latest state list | grep tainted | while read resource; do
    echo "Removing tainted resource: $resource"
    docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace hashicorp/terraform:latest state rm "$resource" || true
done

# 4. Plan again with the fixes
echo "4. Creating new plan with fixes..."
docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace hashicorp/terraform:latest plan -var-file=terraform.tfvars -out=eks-fixed.tfplan

if [ $? -eq 0 ]; then
    echo "✅ Plan successful! You can now run:"
    echo "   docker run --rm -v \$(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace hashicorp/terraform:latest apply eks-fixed.tfplan"
else
    echo "❌ Plan still has errors. Check the output above."
fi