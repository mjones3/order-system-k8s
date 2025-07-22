#!/bin/bash

# Script to fix the failing nodegroup
set -e

CLUSTER_NAME="order-system-cluster"
REGION="us-east-1"
NODEGROUP_NAME="main-20250721180627685800000001"  # The specific failing nodegroup
NODE_ROLE_NAME="main-eks-node-group-20250720234734607900000003"  # The role name from your output

echo "🔧 Fixing failing nodegroup: ${NODEGROUP_NAME}..."

# Check current policies
echo "Current attached policies for role ${NODE_ROLE_NAME}:"
aws iam list-attached-role-policies --role-name ${NODE_ROLE_NAME} --query 'AttachedPolicies[].PolicyName'

# Required policies
REQUIRED_POLICIES=(
  "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
)

# Attach required policies
echo "Ensuring all required policies are attached..."
for policy in "${REQUIRED_POLICIES[@]}"; do
  echo "Attaching policy: ${policy}"
  aws iam attach-role-policy --role-name ${NODE_ROLE_NAME} --policy-arn ${policy} || echo "Policy already attached or error occurred"
done

# Verify policies after attachment
echo "Policies after update:"
aws iam list-attached-role-policies --role-name ${NODE_ROLE_NAME} --query 'AttachedPolicies[].PolicyName'

# Update kubeconfig
echo "📝 Updating kubeconfig..."
aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${REGION}

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

echo "✅ Fix applied to failing nodegroup. If nodes are still not ready, you may need to recycle the nodes."
echo "To recycle the nodes, you can update the desired capacity to 0 and then back to the original value:"
echo "aws eks update-nodegroup-config --cluster-name ${CLUSTER_NAME} --nodegroup-name ${NODEGROUP_NAME} --scaling-config desiredSize=0"
echo "# Wait a few minutes for nodes to terminate"
echo "aws eks update-nodegroup-config --cluster-name ${CLUSTER_NAME} --nodegroup-name ${NODEGROUP_NAME} --scaling-config desiredSize=3"