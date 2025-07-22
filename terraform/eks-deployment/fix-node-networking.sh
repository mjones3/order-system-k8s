#!/bin/bash

# Script to fix node networking directly
set -e

CLUSTER_NAME="order-system-cluster"
REGION="us-east-1"

echo "🔧 Fixing node networking directly..."

# Update kubeconfig
echo "📝 Updating kubeconfig..."
aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${REGION}

# Get the latest nodegroup name
NODEGROUP_NAME=$(aws eks list-nodegroups --cluster-name ${CLUSTER_NAME} --query 'nodegroups[-1]' --output text)
echo "Using nodegroup: ${NODEGROUP_NAME}"

# Get the node instance IDs
echo "🔍 Getting node instance IDs..."
INSTANCE_IDS=$(aws eks describe-nodegroup --cluster-name ${CLUSTER_NAME} --nodegroup-name ${NODEGROUP_NAME} --query 'nodegroup.resources.autoScalingGroups[0].name' --output text | xargs -I {} aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names {} --query 'AutoScalingGroups[0].Instances[*].InstanceId' --output text)
echo "Instance IDs: ${INSTANCE_IDS}"

# Recycle the nodes by terminating the instances
echo "🔄 Recycling nodes by terminating instances..."
for instance in ${INSTANCE_IDS}; do
  echo "Terminating instance: ${instance}"
  aws ec2 terminate-instances --instance-ids ${instance}
done

# Wait for new instances to be launched
echo "⏳ Waiting for new instances to be launched (this may take a few minutes)..."
sleep 180

# Check node status
echo "🔍 Checking node status..."
kubectl get nodes

echo "✅ Node networking fix completed."
echo "If nodes are still not ready, try updating the EKS cluster with the latest CNI addon:"
echo "aws eks update-addon --cluster-name ${CLUSTER_NAME} --addon-name vpc-cni --addon-version latest --resolve-conflicts OVERWRITE"