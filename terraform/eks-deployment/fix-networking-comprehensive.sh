#!/bin/bash

# Comprehensive script to fix EKS networking issues
set -e

CLUSTER_NAME="order-system-cluster"
REGION="us-east-1"

echo "🚀 Starting comprehensive EKS networking fix..."

# Step 1: Check if the CNI addon exists and create it if it doesn't
echo "🔧 Step 1: Checking and installing/updating the CNI addon..."
if aws eks describe-addon --cluster-name ${CLUSTER_NAME} --addon-name vpc-cni &>/dev/null; then
  echo "VPC CNI addon exists, updating it..."
  aws eks update-addon --cluster-name ${CLUSTER_NAME} --addon-name vpc-cni --addon-version latest --resolve-conflicts OVERWRITE
else
  echo "VPC CNI addon doesn't exist, creating it..."
  aws eks create-addon --cluster-name ${CLUSTER_NAME} --addon-name vpc-cni --addon-version latest --resolve-conflicts OVERWRITE
fi

# Step 2: Fix IAM permissions
echo "🔧 Step 2: Fixing IAM permissions..."

# Get the node role name
NODEGROUP_NAME=$(aws eks list-nodegroups --cluster-name ${CLUSTER_NAME} --query 'nodegroups[-1]' --output text)
NODE_ROLE_ARN=$(aws eks describe-nodegroup --cluster-name ${CLUSTER_NAME} --nodegroup-name ${NODEGROUP_NAME} --query 'nodegroup.nodeRole' --output text)
NODE_ROLE=$(echo ${NODE_ROLE_ARN} | awk -F/ '{print $2}')
echo "Node role: ${NODE_ROLE}"

# Attach required policies
aws iam attach-role-policy --role-name ${NODE_ROLE} --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
aws iam attach-role-policy --role-name ${NODE_ROLE} --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
aws iam attach-role-policy --role-name ${NODE_ROLE} --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly

# Step 3: Update kubeconfig
echo "🔧 Step 3: Updating kubeconfig..."
aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${REGION}

# Step 4: Reinstall the CNI plugin
echo "🔧 Step 4: Reinstalling the CNI plugin..."
kubectl delete daemonset -n kube-system aws-node || true
sleep 10
kubectl apply -f https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/master/config/master/aws-k8s-cni.yaml

# Step 5: Wait for the CNI plugin to be installed
echo "⏳ Step 5: Waiting for CNI plugin to be installed..."
sleep 60

# Step 6: Check CNI pods
echo "🔍 Step 6: Checking CNI pods..."
kubectl get pods -n kube-system -l k8s-app=aws-node

# Step 7: Check node status
echo "🔍 Step 7: Checking node status..."
kubectl get nodes

# Step 8: If nodes are still not ready, recycle them
echo "🔧 Step 8: Recycling nodes if needed..."
NOT_READY_COUNT=$(kubectl get nodes | grep -c "NotReady" || true)
if [ "$NOT_READY_COUNT" -gt 0 ]; then
  echo "Found ${NOT_READY_COUNT} nodes in NotReady state. Recycling nodes..."
  
  # Get the instance IDs
  INSTANCE_IDS=$(aws eks describe-nodegroup --cluster-name ${CLUSTER_NAME} --nodegroup-name ${NODEGROUP_NAME} --query 'nodegroup.resources.autoScalingGroups[0].name' --output text | xargs -I {} aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names {} --query 'AutoScalingGroups[0].Instances[*].InstanceId' --output text)
  echo "Instance IDs: ${INSTANCE_IDS}"
  
  # Terminate the instances
  for instance in ${INSTANCE_IDS}; do
    echo "Terminating instance: ${instance}"
    aws ec2 terminate-instances --instance-ids ${instance}
  done
  
  # Wait for new instances to be launched
  echo "⏳ Waiting for new instances to be launched (this may take a few minutes)..."
  sleep 180
  
  # Check node status again
  echo "🔍 Checking node status after recycling..."
  kubectl get nodes
fi

echo "✅ Comprehensive networking fix completed."
echo "If nodes are still not ready, you may need to check the following:"
echo "1. VPC and subnet configuration"
echo "2. Security group rules"
echo "3. EKS cluster configuration"
echo "4. EC2 instance status"