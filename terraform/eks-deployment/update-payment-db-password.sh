#!/bin/bash

# Script to update the payment service database password
set -e

REGION="us-east-1"
DB_IDENTIFIER="terraform-20250721141508796600000003"  # This should be your actual DB identifier
OLD_PASSWORD="paymentpass"
NEW_PASSWORD="password123"

echo "🔧 Updating payment service database password..."

# Update the RDS instance password
aws rds modify-db-instance \
  --db-instance-identifier ${DB_IDENTIFIER} \
  --master-user-password ${NEW_PASSWORD} \
  --apply-immediately \
  --region ${REGION}

echo "✅ Password update initiated. It may take a few minutes to complete."
echo "You can check the status with: aws rds describe-db-instances --db-instance-identifier ${DB_IDENTIFIER} --query 'DBInstances[0].DBInstanceStatus' --region ${REGION}"

# Wait for the database to be available
echo "⏳ Waiting for the database to be available..."
aws rds wait db-instance-available --db-instance-identifier ${DB_IDENTIFIER} --region ${REGION}

echo "✅ Database password updated successfully."
echo "Now you can redeploy the payment service with the new password."