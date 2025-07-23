#!/bin/bash

# Script to fix the payment service database connection
set -e

PAYMENT_DB_ENDPOINT="terraform-20250721141508798300000005.cmw3e40chj7r.us-east-1.rds.amazonaws.com"
DB_USERNAME="paymentuser"
DB_PASSWORD="password123"
DB_NAME="paymentdb"

echo "🔧 Fixing payment service database connection..."

# Step 1: Update the ConfigMap with the correct database endpoint
echo "📝 Updating ConfigMap with correct database endpoint..."
cat > payment-service-config-fix.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: payment-service-config
  namespace: payment-service
data:
  # Database connection information
  PG_HOST: "${PAYMENT_DB_ENDPOINT}"
  PG_CONTAINER: "postgres-paymentdb"
  DATASOURCE_PORT: "5432"
  ENVIRONMENT: "production"
  PG_DB: "${DB_NAME}"
  PG_USER: "${DB_USERNAME}"
  PG_PASS: "${DB_PASSWORD}"
  PG_PORT: "5432"
  
  # Spring Boot specific configuration
  SPRING_PROFILES_ACTIVE: "production"
  SPRING_DATASOURCE_URL: "jdbc:postgresql://${PAYMENT_DB_ENDPOINT}:5432/${DB_NAME}"
  SPRING_DATASOURCE_USERNAME: "${DB_USERNAME}"
  SPRING_DATASOURCE_PASSWORD: "${DB_PASSWORD}"
  
  # Standard JDBC URL for other frameworks
  DATASOURCE_URL: "jdbc:postgresql://${PAYMENT_DB_ENDPOINT}:5432/${DB_NAME}"
  
  # Flag to indicate environment
  DEPLOYMENT_ENV: "cloud"
EOF
kubectl apply -f payment-service-config-fix.yaml

# Step 2: Restart the deployment
echo "🔄 Restarting payment service deployment..."
kubectl rollout restart deployment payment-service -n payment-service

# Step 3: Wait for the deployment to be ready
echo "⏳ Waiting for deployment to be ready..."
kubectl rollout status deployment/payment-service -n payment-service --timeout=300s

# Step 4: Check the logs for any database connection issues
echo "🔍 Checking payment service logs for database connection issues..."
POD_NAME=$(kubectl get pods -n payment-service -l app=payment-service -o jsonpath='{.items[0].metadata.name}')
kubectl logs ${POD_NAME} -n payment-service | grep -i "database\|connection\|postgres\|sql\|error" | tail -20

echo "✅ Fix completed. If you still see database connection issues, please check the logs with:"
echo "kubectl logs -n payment-service -l app=payment-service"