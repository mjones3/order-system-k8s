#!/bin/bash

# Script to scale down and up a nodegroup to verify CNI plugin
set -e

CLUSTER_NAME="order-system-cluster"
REGION="us-east-1"

# Update kubeconfig
echo "📝 Updating kubeconfig..."
aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${REGION}

# Get the nodegroup name
NODEGROUP_NAME=$(aws eks list-nodegroups --cluster-name ${CLUSTER_NAME} --query 'nodegroups[-1]' --output text)
echo "🔍 Working with nodegroup: ${NODEGROUP_NAME}"

# Get current desired size
CURRENT_SIZE=$(aws eks describe-nodegroup --cluster-name ${CLUSTER_NAME} --nodegroup-name ${NODEGROUP_NAME} --query 'nodegroup.scalingConfig.desiredSize' --output text)
echo "Current desired size: ${CURRENT_SIZE}"

# Scale down to 0 nodes
echo "⬇️ Scaling down nodegroup to 0 nodes..."
aws eks update-nodegroup-config \
  --cluster-name ${CLUSTER_NAME} \
  --nodegroup-name ${NODEGROUP_NAME} \
  --scaling-config desiredSize=0

# Wait for nodes to terminate
echo "⏳ Waiting for nodes to terminate..."
while [ "$(kubectl get nodes | grep -v NAME | wc -l)" -gt 0 ]; do
  echo "Nodes still terminating..."
  kubectl get nodes
  sleep 30
done
echo "✅ All nodes terminated."

# Scale back up to original size
echo "⬆️ Scaling back up to ${CURRENT_SIZE} nodes..."
aws eks update-nodegroup-config \
  --cluster-name ${CLUSTER_NAME} \
  --nodegroup-name ${NODEGROUP_NAME} \
  --scaling-config desiredSize=${CURRENT_SIZE}

# Wait for nodes to come up
echo "⏳ Waiting for new nodes to come up (this may take a few minutes)..."
sleep 60

# Check node status in a loop
echo "🔍 Checking node status..."
for i in {1..10}; do
  echo "Check $i of 10:"
  kubectl get nodes
  READY_COUNT=$(kubectl get nodes | grep -c "\sReady\s" || true)
  NOT_READY_COUNT=$(kubectl get nodes | grep -c "NotReady" || true)
  TOTAL_COUNT=$(kubectl get nodes | grep -v NAME | wc -l)
  
  if [ "$READY_COUNT" -eq "$TOTAL_COUNT" ] && [ "$TOTAL_COUNT" -gt 0 ]; then
    echo "✅ All nodes are Ready! CNI plugin is working correctly."
    break
  elif [ "$i" -eq 10 ]; then
    echo "❌ Some nodes are still not ready after 10 checks. CNI plugin may still have issues."
  else
    echo "⏳ Waiting for more nodes to become Ready... ($READY_COUNT/$TOTAL_COUNT ready)"
    sleep 30
  fi
done

# Final node status
echo "📊 Final node status:"
kubectl get nodes

echo "✅ Nodegroup scaling completed."