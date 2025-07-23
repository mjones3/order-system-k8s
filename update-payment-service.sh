#!/bin/bash

# Script to update and redeploy the payment service
set -e

echo "🔄 Rebuilding and redeploying payment service..."

# Step 1: Build the payment service
echo "🏗️ Building payment service..."
cd apps/payment-service
./mvnw clean package -DskipTests

# Step 2: Push the image to ECR
echo "📤 Pushing image to ECR..."
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 294417223953.dkr.ecr.us-east-1.amazonaws.com
docker build -t 294417223953.dkr.ecr.us-east-1.amazonaws.com/payment-service:latest .
docker push 294417223953.dkr.ecr.us-east-1.amazonaws.com/payment-service:latest

# Step 3: Restart the deployment
echo "🔄 Restarting deployment..."
kubectl rollout restart deployment payment-service -n payment-service

# Step 4: Wait for the deployment to be ready
echo "⏳ Waiting for deployment to be ready..."
kubectl rollout status deployment/payment-service -n payment-service --timeout=300s

echo "✅ Payment service updated and redeployed."
echo "You can now access the actuator endpoints at:"
echo "http://k8s-payments-payments-39b18f3a4b-1266732517.us-east-1.elb.amazonaws.com/actuator"