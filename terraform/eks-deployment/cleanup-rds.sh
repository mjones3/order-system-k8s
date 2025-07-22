#!/bin/bash

echo "🧹 Cleaning up conflicting RDS resources..."

# First, check what RDS instances exist
echo "📊 Current RDS instances:"
aws rds describe-db-instances --query 'DBInstances[?contains(DBInstanceIdentifier, `order`) || contains(DBInstanceIdentifier, `inventory`) || contains(DBInstanceIdentifier, `payment`)].{Name:DBInstanceIdentifier,Status:DBInstanceStatus,VPC:DBSubnetGroup.VpcId}' --output table

echo ""
echo "📊 Current DB Subnet Groups:"
aws rds describe-db-subnet-groups --query 'DBSubnetGroups[?contains(DBSubnetGroupName, `order`) || contains(DBSubnetGroupName, `inventory`) || contains(DBSubnetGroupName, `payment`)].{Name:DBSubnetGroupName,VPC:VpcId,Subnets:Subnets[].SubnetIdentifier}' --output table

echo ""
echo "⚠️  We need to delete old DB subnet groups that are in the wrong VPC"
echo "This will require deleting any RDS instances using them first."
echo ""
echo "Do you want to proceed with cleanup? (y/N)"
read -r response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "❌ Cleanup cancelled"
    exit 1
fi

# Delete RDS instances first (they prevent subnet group deletion)
echo "🗑️  Deleting RDS instances..."
for db in $(aws rds describe-db-instances --query 'DBInstances[?contains(DBInstanceIdentifier, `terraform-2025`)].DBInstanceIdentifier' --output text); do
    echo "Deleting RDS instance: $db"
    aws rds delete-db-instance --db-instance-identifier "$db" --skip-final-snapshot --delete-automated-backups
done

# Wait for RDS instances to be deleted
echo "⏳ Waiting for RDS instances to be deleted..."
sleep 30

# Delete old subnet groups
echo "🗑️  Deleting old DB subnet groups..."
for group in "inventory-system-db-subnet-group" "order-system-db-subnet-group" "payment-system-db-subnet-group"; do
    echo "Attempting to delete: $group"
    aws rds delete-db-subnet-group --db-subnet-group-name "$group" 2>/dev/null || echo "  (already deleted or doesn't exist)"
done

echo "✅ Cleanup completed!"
echo "💡 Now you can run terraform apply again"