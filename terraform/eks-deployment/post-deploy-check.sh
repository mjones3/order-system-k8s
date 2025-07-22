#!/bin/bash

# Post-deployment check script for EKS
set -e

CLUSTER_NAME="order-system-cluster"
REGION="us-east-1"

echo "🔍 Running post-deployment checks for EKS cluster: ${CLUSTER_NAME}"

# Update kubeconfig
echo "📝 Updating kubeconfig..."
aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${REGION}

# Verify CNI plugin is working
echo "🔍 Verifying CNI plugin..."
kubectl get pods -n kube-system -l k8s-app=aws-node
kubectl wait --for=condition=Ready pods -l k8s-app=aws-node -n kube-system --timeout=120s || {
  echo "⚠️ CNI plugin pods are not ready. Attempting to fix..."
  
  # Get the node role name
  NODEGROUP_NAME=$(aws eks list-nodegroups --cluster-name ${CLUSTER_NAME} --query 'nodegroups[-1]' --output text)
  NODE_ROLE_ARN=$(aws eks describe-nodegroup --cluster-name ${CLUSTER_NAME} --nodegroup-name ${NODEGROUP_NAME} --query 'nodegroup.nodeRole' --output text)
  NODE_ROLE=$(echo ${NODE_ROLE_ARN} | awk -F/ '{print $2}')
  
  # Attach required policies
  echo "📎 Attaching required policies to node role..."
  aws iam attach-role-policy --role-name ${NODE_ROLE} --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy || true
  aws iam attach-role-policy --role-name ${NODE_ROLE} --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy || true
  aws iam attach-role-policy --role-name ${NODE_ROLE} --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly || true
  
  # Restart CNI pods
  echo "🔄 Restarting CNI pods..."
  kubectl delete pods -n kube-system -l k8s-app=aws-node
  
  # Wait for CNI pods to restart
  echo "⏳ Waiting for CNI pods to restart..."
  sleep 30
  kubectl get pods -n kube-system -l k8s-app=aws-node
}

# Check node status
echo "🔍 Checking node status..."
kubectl get nodes

# Check CoreDNS
echo "🔍 Checking CoreDNS..."
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl wait --for=condition=Ready pods -l k8s-app=kube-dns -n kube-system --timeout=60s || echo "⚠️ CoreDNS pods are not ready"

# Check kube-proxy
echo "🔍 Checking kube-proxy..."
kubectl get pods -n kube-system -l k8s-app=kube-proxy
kubectl wait --for=condition=Ready pods -l k8s-app=kube-proxy -n kube-system --timeout=60s || echo "⚠️ kube-proxy pods are not ready"

# Check cluster services
echo "🔍 Checking cluster services..."
kubectl get svc --all-namespaces

echo "✅ Post-deployment checks completed."