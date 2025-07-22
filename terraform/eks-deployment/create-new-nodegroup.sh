#!/bin/bash

# Script to create a new nodegroup
set -e

CLUSTER_NAME="order-system-cluster"
REGION="us-east-1"

echo "🚀 Creating a new nodegroup for cluster: ${CLUSTER_NAME}"

# Get the latest nodegroup name
LATEST_NODEGROUP=$(aws eks list-nodegroups --cluster-name ${CLUSTER_NAME} --query 'nodegroups[-1]' --output text)
echo "Using latest nodegroup as template: ${LATEST_NODEGROUP}"

# Get the configuration of the latest nodegroup
NODE_ROLE_ARN=$(aws eks describe-nodegroup --cluster-name ${CLUSTER_NAME} --nodegroup-name ${LATEST_NODEGROUP} --query 'nodegroup.nodeRole' --output text)
SUBNETS=$(aws eks describe-nodegroup --cluster-name ${CLUSTER_NAME} --nodegroup-name ${LATEST_NODEGROUP} --query 'nodegroup.subnets' --output json)
INSTANCE_TYPES=$(aws eks describe-nodegroup --cluster-name ${CLUSTER_NAME} --nodegroup-name ${LATEST_NODEGROUP} --query 'nodegroup.instanceTypes' --output json)
AMI_TYPE=$(aws eks describe-nodegroup --cluster-name ${CLUSTER_NAME} --nodegroup-name ${LATEST_NODEGROUP} --query 'nodegroup.amiType' --output text)
DISK_SIZE=$(aws eks describe-nodegroup --cluster-name ${CLUSTER_NAME} --nodegroup-name ${LATEST_NODEGROUP} --query 'nodegroup.diskSize' --output text || echo "20")
MIN_SIZE=$(aws eks describe-nodegroup --cluster-name ${CLUSTER_NAME} --nodegroup-name ${LATEST_NODEGROUP} --query 'nodegroup.scalingConfig.minSize' --output text)
MAX_SIZE=$(aws eks describe-nodegroup --cluster-name ${CLUSTER_NAME} --nodegroup-name ${LATEST_NODEGROUP} --query 'nodegroup.scalingConfig.maxSize' --output text)
DESIRED_SIZE=$(aws eks describe-nodegroup --cluster-name ${CLUSTER_NAME} --nodegroup-name ${LATEST_NODEGROUP} --query 'nodegroup.scalingConfig.desiredSize' --output text)

# Get the node role name
NODE_ROLE=$(echo ${NODE_ROLE_ARN} | awk -F/ '{print $2}')
echo "Node role: ${NODE_ROLE}"

# Attach required policies
echo "📎 Attaching required policies to node role..."
aws iam attach-role-policy --role-name ${NODE_ROLE} --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy || true
aws iam attach-role-policy --role-name ${NODE_ROLE} --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy || true
aws iam attach-role-policy --role-name ${NODE_ROLE} --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly || true

# Create a new nodegroup
NEW_NODEGROUP_NAME="fixed-nodegroup-$(date +%Y%m%d%H%M%S)"
echo "Creating new nodegroup: ${NEW_NODEGROUP_NAME}"

# Create the new nodegroup
aws eks create-nodegroup \
  --cluster-name ${CLUSTER_NAME} \
  --nodegroup-name ${NEW_NODEGROUP_NAME} \
  --node-role ${NODE_ROLE_ARN} \
  --subnets $(echo ${SUBNETS} | jq -r 'join(" ")') \
  --instance-types $(echo ${INSTANCE_TYPES} | jq -r '.[0]') \
  --ami-type ${AMI_TYPE} \
  --disk-size ${DISK_SIZE} \
  --scaling-config minSize=${MIN_SIZE},maxSize=${MAX_SIZE},desiredSize=${DESIRED_SIZE} \
  --tags project=order-system,Environment=production

echo "⏳ Waiting for new nodegroup to be created (this may take several minutes)..."
aws eks wait nodegroup-active --cluster-name ${CLUSTER_NAME} --nodegroup-name ${NEW_NODEGROUP_NAME}

echo "✅ New nodegroup created successfully: ${NEW_NODEGROUP_NAME}"

# Update kubeconfig
echo "📝 Updating kubeconfig..."
aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${REGION}

# Check node status
echo "🔍 Checking node status:"
kubectl get nodes

echo "✅ New nodegroup creation completed."