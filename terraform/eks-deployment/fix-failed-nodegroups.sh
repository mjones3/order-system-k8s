#!/bin/bash

# Script to fix failed nodegroups
set -e

CLUSTER_NAME="order-system-cluster"
REGION="us-east-1"

echo "🔧 Fixing failed nodegroups for cluster: ${CLUSTER_NAME}"

# List all nodegroups
echo "📋 Listing all nodegroups:"
NODEGROUPS=$(aws eks list-nodegroups --cluster-name ${CLUSTER_NAME} --query 'nodegroups' --output text)
echo "${NODEGROUPS}"

# Find failed nodegroups
FAILED_NODEGROUPS=$(aws eks list-nodegroups --cluster-name ${CLUSTER_NAME} --query 'nodegroups' --output text | xargs -n1 | xargs -I{} sh -c "aws eks describe-nodegroup --cluster-name ${CLUSTER_NAME} --nodegroup-name {} --query 'nodegroup.status' --output text | grep -q 'CREATE_FAILED' && echo {}" || true)

if [ -z "${FAILED_NODEGROUPS}" ]; then
  echo "✅ No failed nodegroups found."
  exit 0
fi

echo "❌ Found nodegroups in CREATE_FAILED state: ${FAILED_NODEGROUPS}"

# Create a new nodegroup with the same configuration
echo "🔧 Creating a new nodegroup to replace the failed ones..."

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

# Check node status
echo "🔍 Checking node status:"
kubectl get nodes

echo "✅ Nodegroup fix completed."
echo "You can now delete the failed nodegroups if desired:"
for ng in ${FAILED_NODEGROUPS}; do
  echo "aws eks delete-nodegroup --cluster-name ${CLUSTER_NAME} --nodegroup-name ${ng}"
done