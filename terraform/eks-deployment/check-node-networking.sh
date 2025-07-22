#!/bin/bash

# Script to check node networking
set -e

# Get the latest node name
NODE_NAME=$(kubectl get nodes --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}')
echo "🔍 Checking networking for node: ${NODE_NAME}"

# Check node status
echo -e "\n📊 Node Status:"
kubectl get node ${NODE_NAME} -o wide

# Check node conditions
echo -e "\n📊 Node Conditions:"
kubectl get node ${NODE_NAME} -o jsonpath='{.status.conditions[*].type}{"\t"}{.status.conditions[*].status}{"\n"}' | tr -s '\t' '\n' | paste - -

# Check CNI pods
echo -e "\n📊 CNI Pods Status:"
kubectl get pods -n kube-system -l k8s-app=aws-node

# Check CNI logs for the node
echo -e "\n📊 CNI Logs for the node:"
POD_NAME=$(kubectl get pods -n kube-system -l k8s-app=aws-node -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n kube-system ${POD_NAME} --tail=20

# Try to run a test pod on the node
echo -e "\n📊 Testing pod scheduling on the node:"
kubectl delete pod test-pod --ignore-not-found
kubectl run test-pod --image=nginx --restart=Never --overrides="{\"spec\": {\"nodeSelector\": {\"kubernetes.io/hostname\": \"${NODE_NAME}\"}}}"

# Wait for the pod to start
echo "⏳ Waiting for test pod to start..."
sleep 10

# Check test pod status
echo -e "\n📊 Test Pod Status:"
kubectl get pod test-pod

# If the pod is running, check networking from inside the pod
if [ "$(kubectl get pod test-pod -o jsonpath='{.status.phase}')" == "Running" ]; then
  echo -e "\n📊 Testing network connectivity from inside the pod:"
  kubectl exec -it test-pod -- ping -c 3 8.8.8.8 || echo "Ping failed - network connectivity issues"
else
  echo "❌ Test pod is not running - cannot test network connectivity"
fi

echo -e "\n✅ Node networking check completed."