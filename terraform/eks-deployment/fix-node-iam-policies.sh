#!/bin/bash

# Script to check and fix EKS node IAM policies
set -e

CLUSTER_NAME="order-system-cluster"
REGION="us-east-1"

echo "🔧 Checking and fixing EKS node IAM policies..."

# Get the latest nodegroup name
NODEGROUP_NAME=$(aws eks list-nodegroups --cluster-name ${CLUSTER_NAME} --query 'nodegroups[-1]' --output text)
echo "Using nodegroup: ${NODEGROUP_NAME}"

# Get the full node role ARN
NODE_ROLE_ARN=$(aws eks describe-nodegroup --cluster-name ${CLUSTER_NAME} --nodegroup-name ${NODEGROUP_NAME} --query 'nodegroup.nodeRole' --output text)
echo "Node role ARN: ${NODE_ROLE_ARN}"

# Extract just the role name from the ARN
NODE_ROLE=$(echo ${NODE_ROLE_ARN} | awk -F/ '{print $2}')
echo "Node role name: ${NODE_ROLE}"

# Check current policies
echo "Current attached policies:"
aws iam list-attached-role-policies --role-name ${NODE_ROLE} --query 'AttachedPolicies[].PolicyName'

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
  aws iam attach-role-policy --role-name ${NODE_ROLE} --policy-arn ${policy} || echo "Policy already attached or error occurred"
done

# Verify policies after attachment
echo "Policies after update:"
aws iam list-attached-role-policies --role-name ${NODE_ROLE} --query 'AttachedPolicies[].PolicyName'

echo "✅ IAM policies check and fix completed."
echo "You may need to restart the nodes or the aws-node pods for changes to take effect."
echo "To restart aws-node pods, run: kubectl delete pods -n kube-system -l k8s-app=aws-node"