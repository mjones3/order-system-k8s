#!/bin/bash

# Script to fix CNI issues on the EKS cluster
set -e

CLUSTER_NAME="order-system-cluster"
REGION="us-east-1"

echo "🔧 Fixing CNI issues on EKS cluster ${CLUSTER_NAME}..."

# Update kubeconfig
echo "📝 Updating kubeconfig..."
aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${REGION}

# Check if the aws-node pods are running
echo "🔍 Checking aws-node pods..."
kubectl get pods -n kube-system -l k8s-app=aws-node

# Restart the aws-node pods
echo "🔄 Restarting aws-node pods..."
kubectl delete pods -n kube-system -l k8s-app=aws-node

# Wait for the pods to restart
echo "⏳ Waiting for aws-node pods to restart..."
sleep 30

# Check the status of the aws-node pods
echo "🔍 Checking aws-node pods status..."
kubectl get pods -n kube-system -l k8s-app=aws-node

# Check node status
echo "🔍 Checking node status..."
kubectl get nodes

echo "✅ CNI fix applied. If nodes are still not ready, you may need to apply the Terraform changes to add the proper IAM roles."
echo "Run: docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace hashicorp/terraform:latest apply -target=module.eks"