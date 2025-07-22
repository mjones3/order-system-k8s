#!/bin/bash

# Script to fix CNI pods in CrashLoopBackOff state
set -e

CLUSTER_NAME="order-system-cluster"
REGION="us-east-1"

echo "🔧 Fixing CNI pods in CrashLoopBackOff state..."

# Update kubeconfig
echo "📝 Updating kubeconfig..."
aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${REGION}

# Get the node role name
echo "🔍 Getting node role name..."
NODEGROUP_NAME=$(aws eks list-nodegroups --cluster-name ${CLUSTER_NAME} --query 'nodegroups[-1]' --output text)
NODE_ROLE_ARN=$(aws eks describe-nodegroup --cluster-name ${CLUSTER_NAME} --nodegroup-name ${NODEGROUP_NAME} --query 'nodegroup.nodeRole' --output text)
NODE_ROLE=$(echo ${NODE_ROLE_ARN} | awk -F/ '{print $2}')
echo "Node role: ${NODE_ROLE}"

# Attach required policies
echo "📎 Attaching required policies to node role..."
aws iam attach-role-policy --role-name ${NODE_ROLE} --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy || true
aws iam attach-role-policy --role-name ${NODE_ROLE} --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy || true
aws iam attach-role-policy --role-name ${NODE_ROLE} --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly || true

# Create a service account for the CNI plugin
echo "👤 Creating service account for CNI plugin..."
cat <<EOF > aws-node-sa.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-node
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: ${NODE_ROLE_ARN}
EOF

kubectl apply -f aws-node-sa.yaml

# Delete the aws-node daemonset
echo "🗑️ Deleting aws-node daemonset..."
kubectl delete daemonset aws-node -n kube-system || true

# Wait for the daemonset to be deleted
echo "⏳ Waiting for aws-node daemonset to be deleted..."
sleep 10

# Download the latest CNI plugin manifest
echo "📥 Downloading latest CNI plugin manifest..."
curl -o aws-k8s-cni.yaml https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/master/config/master/aws-k8s-cni.yaml

# Modify the CNI plugin manifest to use the correct region
echo "✏️ Modifying CNI plugin manifest to use the correct region..."
sed -i '' "s|602401143452.dkr.ecr.us-west-2.amazonaws.com|602401143452.dkr.ecr.${REGION}.amazonaws.com|g" aws-k8s-cni.yaml

# Apply the CNI plugin manifest
echo "📦 Applying CNI plugin manifest..."
kubectl apply -f aws-k8s-cni.yaml

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

echo "✅ CNI pod fix completed."
echo "If nodes are still not ready, you may need to create a new nodegroup."