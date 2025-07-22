#!/bin/bash

# Script to check the status of the CNI plugin
set -e

CLUSTER_NAME="order-system-cluster"
REGION="us-east-1"

echo "🔍 Checking CNI plugin status for cluster: ${CLUSTER_NAME}"

# Update kubeconfig
echo "📝 Updating kubeconfig..."
aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${REGION}

# Check if the CNI plugin is installed as an addon
echo "📋 Checking if CNI plugin is installed as an addon:"
if aws eks describe-addon --cluster-name ${CLUSTER_NAME} --addon-name vpc-cni &>/dev/null; then
  echo "✅ VPC CNI addon is installed"
  aws eks describe-addon --cluster-name ${CLUSTER_NAME} --addon-name vpc-cni --query 'addon.{Name:addonName,Version:addonVersion,Status:status}'
else
  echo "❌ VPC CNI addon is not installed as a managed addon"
fi

# Check CNI pods
echo -e "\n📊 CNI pods status:"
kubectl get pods -n kube-system -l k8s-app=aws-node || echo "No CNI pods found"

# Check CNI logs
echo -e "\n📊 CNI logs (last 20 lines):"
CNI_POD=$(kubectl get pods -n kube-system -l k8s-app=aws-node -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "${CNI_POD}" ]; then
  kubectl logs -n kube-system ${CNI_POD} --tail=20
else
  echo "No CNI pods found to check logs"
fi

# Check CNI configuration
echo -e "\n📊 CNI configuration:"
kubectl describe daemonset aws-node -n kube-system || echo "CNI daemonset not found"

# Check node status
echo -e "\n📊 Node status:"
kubectl get nodes || echo "Unable to get node status"

echo -e "\n✅ CNI plugin status check completed."