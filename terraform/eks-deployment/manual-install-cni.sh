#!/bin/bash

# Script to manually install the CNI plugin
set -e

CLUSTER_NAME="order-system-cluster"
REGION="us-east-1"

echo "🔧 Manually installing CNI plugin..."

# Update kubeconfig
echo "📝 Updating kubeconfig..."
aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${REGION}

# Remove existing CNI plugin
echo "🗑️ Removing existing CNI plugin..."
kubectl delete daemonset -n kube-system aws-node || true

# Install the latest version of the CNI plugin
echo "📦 Installing latest CNI plugin..."
kubectl apply -f https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/master/config/master/aws-k8s-cni.yaml

# Wait for the CNI plugin to be installed
echo "⏳ Waiting for CNI plugin to be installed..."
sleep 30

# Check CNI pods
echo "🔍 Checking CNI pods..."
kubectl get pods -n kube-system -l k8s-app=aws-node

# Wait for pods to be running
echo "⏳ Waiting for CNI pods to be running..."
kubectl wait --for=condition=Ready pods -l k8s-app=aws-node -n kube-system --timeout=120s || true

# Check node status
echo "🔍 Checking node status..."
kubectl get nodes

echo "✅ Manual CNI plugin installation completed."