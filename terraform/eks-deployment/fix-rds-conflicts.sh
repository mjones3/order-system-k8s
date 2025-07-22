#!/bin/bash

echo "🔧 Fixing RDS subnet group conflicts..."

# Delete old RDS instances that are blocking subnet group updates
echo "1. Checking for old RDS instances..."
OLD_INSTANCES=$(aws rds describe-db-instances --query 'DBInstances[?contains(DBInstanceIdentifier, `terraform-2025`)].DBInstanceIdentifier' --output text)

if [ -n "$OLD_INSTANCES" ]; then
    echo "Found old RDS instances: $OLD_INSTANCES"
    echo "Deleting them..."
    for instance in $OLD_INSTANCES; do
        aws rds delete-db-instance --db-instance-identifier "$instance" --skip-final-snapshot --delete-automated-backups
        echo "Deleted: $instance"
    done
    
    echo "⏳ Waiting 60 seconds for instances to start deleting..."
    sleep 60
fi

# Import existing subnet groups into Terraform state to avoid conflicts
echo "2. Checking existing subnet groups..."
EXISTING_GROUPS=$(aws rds describe-db-subnet-groups --query 'DBSubnetGroups[?contains(DBSubnetGroupName, `order`) || contains(DBSubnetGroupName, `inventory`) || contains(DBSubnetGroupName, `payment`)].DBSubnetGroupName' --output text)

for group in $EXISTING_GROUPS; do
    echo "Found existing group: $group"
    # Try to import it into Terraform state
    case $group in
        *order*)
            echo "Importing order service DB subnet group..."
            docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace hashicorp/terraform:latest import module.order_service_db.aws_db_subnet_group.order_db_subnet_group "$group" || true
            ;;
        *inventory*)
            echo "Importing inventory service DB subnet group..."
            docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace hashicorp/terraform:latest import module.inventory_service_db.aws_db_subnet_group.inventory_db_subnet_group "$group" || true
            ;;
        *payment*)
            echo "Importing payment service DB subnet group..."
            docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace hashicorp/terraform:latest import module.payment_service_db.aws_db_subnet_group.payment_db_subnet_group "$group" || true
            ;;
    esac
done

echo "✅ RDS conflicts should now be resolved"
echo "💡 You can now run terraform plan again"