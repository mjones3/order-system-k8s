#!/bin/bash

# Script to directly install the CNI plugin without using EKS addons
set -e

CLUSTER_NAME="order-system-cluster"
REGION="us-east-1"

echo "🚀 Installing CNI plugin directly..."

# Update kubeconfig
echo "📝 Updating kubeconfig..."
aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${REGION}

# Step 1: Fix IAM permissions
echo "🔧 Step 1: Fixing IAM permissions..."

# Get the node role name
NODEGROUP_NAME=$(aws eks list-nodegroups --cluster-name ${CLUSTER_NAME} --query 'nodegroups[-1]' --output text)
NODE_ROLE_ARN=$(aws eks describe-nodegroup --cluster-name ${CLUSTER_NAME} --nodegroup-name ${NODEGROUP_NAME} --query 'nodegroup.nodeRole' --output text)
NODE_ROLE=$(echo ${NODE_ROLE_ARN} | awk -F/ '{print $2}')
echo "Node role: ${NODE_ROLE}"

# Attach required policies
echo "📎 Attaching required policies to node role..."
aws iam attach-role-policy --role-name ${NODE_ROLE} --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy || true
aws iam attach-role-policy --role-name ${NODE_ROLE} --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy || true
aws iam attach-role-policy --role-name ${NODE_ROLE} --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly || true

# Step 2: Download the CNI plugin manifest
echo "🔧 Step 2: Downloading CNI plugin manifest..."
curl -o aws-k8s-cni.yaml https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/master/config/master/aws-k8s-cni.yaml

# Step 3: Apply the CNI plugin manifest
echo "🔧 Step 3: Applying CNI plugin manifest..."
kubectl apply -f aws-k8s-cni.yaml

# Step 4: Wait for the CNI plugin to be installed
echo "⏳ Step 4: Waiting for CNI plugin to be installed..."
sleep 30

# Step 5: Check CNI pods
echo "🔍 Step 5: Checking CNI pods..."
kubectl get pods -n kube-system -l k8s-app=aws-node

# Step 6: Wait for pods to be running
echo "⏳ Step 6: Waiting for CNI pods to be running..."
kubectl wait --for=condition=Ready pods -l k8s-app=aws-node -n kube-system --timeout=120s || true

# Step 7: Check node status
echo "🔍 Step 7: Checking node status..."
kubectl get nodes

echo "✅ CNI plugin installation completed."
echo "If nodes are still not ready, try recycling them with the scale-nodegroup.sh script."