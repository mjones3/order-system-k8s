#!/bin/bash

# Script to check the status of EKS nodegroups
set -e

CLUSTER_NAME="order-system-cluster"
REGION="us-east-1"

echo "🔍 Checking nodegroup status for cluster: ${CLUSTER_NAME}"

# List all nodegroups
echo "📋 Listing all nodegroups:"
NODEGROUPS=$(aws eks list-nodegroups --cluster-name ${CLUSTER_NAME} --query 'nodegroups' --output text)
echo "${NODEGROUPS}"

# Check status of each nodegroup
echo -e "\n📊 Status of each nodegroup:"
for ng in ${NODEGROUPS}; do
  echo -e "\n🔍 Nodegroup: ${ng}"
  aws eks describe-nodegroup --cluster-name ${CLUSTER_NAME} --nodegroup-name ${ng} \
    --query '{Status:nodegroup.status, DesiredSize:nodegroup.scalingConfig.desiredSize, MinSize:nodegroup.scalingConfig.minSize, MaxSize:nodegroup.scalingConfig.maxSize, InstanceTypes:nodegroup.instanceTypes, Subnets:nodegroup.subnets, Health:nodegroup.health}'
done

# Check if any nodegroup is in CREATE_FAILED state
FAILED_NODEGROUPS=$(aws eks list-nodegroups --cluster-name ${CLUSTER_NAME} --query 'nodegroups' --output text | xargs -n1 | xargs -I{} sh -c "aws eks describe-nodegroup --cluster-name ${CLUSTER_NAME} --nodegroup-name {} --query 'nodegroup.status' --output text | grep -q 'CREATE_FAILED' && echo {}" || true)

if [ -n "${FAILED_NODEGROUPS}" ]; then
  echo -e "\n❌ Found nodegroups in CREATE_FAILED state: ${FAILED_NODEGROUPS}"
  echo -e "\n📊 Detailed health information for failed nodegroups:"
  for ng in ${FAILED_NODEGROUPS}; do
    echo -e "\n🔍 Failed nodegroup: ${ng}"
    aws eks describe-nodegroup --cluster-name ${CLUSTER_NAME} --nodegroup-name ${ng} --query 'nodegroup.health'
  done
fi

# Check node status in Kubernetes
echo -e "\n📊 Kubernetes node status:"
kubectl get nodes || echo "Unable to get node status from Kubernetes"

echo -e "\n✅ Nodegroup status check completed."