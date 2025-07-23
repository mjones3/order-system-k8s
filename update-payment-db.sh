#!/bin/bash

# Script to update the payment service database password
set -e

echo "🚀 Updating payment service database password..."

# Update the RDS instance password
echo "📝 Updating RDS instance password..."
aws rds modify-db-instance --db-instance-identifier terraform-20250721141508798300000005 --master-user-password password123 --apply-immediately

# Wait for the RDS instance to be updated
echo "⏳ Waiting for RDS instance to be updated..."
sleep 30

# Create ConfigMap
echo "📝 Creating ConfigMap..."
cat > payment-service-config.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: payment-service-config
  namespace: payment-service
data:
  # Database connection information
  PG_HOST: "terraform-20250721141508798300000005.cmw3e40chj7r.us-east-1.rds.amazonaws.com"
  PG_CONTAINER: "postgres-paymentdb"
  DATASOURCE_PORT: "5432"
  ENVIRONMENT: "production"
  PG_DB: "paymentdb"
  PG_USER: "paymentuser"
  PG_PASS: "password123"
  PG_PORT: "5432"
  
  # Spring Boot specific configuration
  SPRING_PROFILES_ACTIVE: "production"
  SPRING_DATASOURCE_URL: "jdbc:postgresql://terraform-20250721141508798300000005.cmw3e40chj7r.us-east-1.rds.amazonaws.com:5432/paymentdb"
  SPRING_DATASOURCE_USERNAME: "paymentuser"
  SPRING_DATASOURCE_PASSWORD: "password123"
  
  # Standard JDBC URL for other frameworks
  DATASOURCE_URL: "jdbc:postgresql://terraform-20250721141508798300000005.cmw3e40chj7r.us-east-1.rds.amazonaws.com:5432/paymentdb"
  
  # Flag to indicate environment
  DEPLOYMENT_ENV: "cloud"
EOF

# Apply the ConfigMap
echo "📝 Applying ConfigMap..."
kubectl apply -f payment-service-config.yaml

# Restart the payment service deployment
echo "🔄 Restarting payment service deployment..."
kubectl rollout restart deployment payment-service -n payment-service

# Wait for the deployment to be ready
echo "⏳ Waiting for deployment to be ready..."
kubectl rollout status deployment/payment-service -n payment-service --timeout=300s

# Check pods
echo "🔍 Checking payment service pods..."
kubectl get pods -n payment-service -l app=payment-service

# Clean up
rm -f payment-service-config.yaml

echo "✅ Payment service database password update completed."