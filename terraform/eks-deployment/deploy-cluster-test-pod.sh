#!/bin/bash

# Script to deploy a test pod anywhere in the cluster
set -e

echo "🚀 Deploying cluster test pod..."

# Create a test pod YAML
cat <<EOF > cluster-test-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: cluster-test-pod
spec:
  containers:
  - name: busybox
    image: busybox:latest
    command:
      - /bin/sh
      - -c
      - "ping 8.8.8.8 & sleep 3600"
EOF

# Delete any existing pod
kubectl delete pod cluster-test-pod --ignore-not-found

# Apply the new pod
kubectl apply -f cluster-test-pod.yaml

# Wait for the pod to be created
echo "⏳ Waiting for pod to be created..."
sleep 5

# Check pod status
echo -e "\n📊 Pod Status:"
kubectl get pod cluster-test-pod -o wide

# Wait for the pod to be running
echo "⏳ Waiting for pod to start running (up to 60 seconds)..."
for i in {1..12}; do
  STATUS=$(kubectl get pod cluster-test-pod -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
  if [ "$STATUS" == "Running" ]; then
    echo "✅ Pod is running!"
    break
  fi
  echo "Current status: $STATUS"
  sleep 5
done

# If pod is running, check which node it's on
if [ "$(kubectl get pod cluster-test-pod -o jsonpath='{.status.phase}' 2>/dev/null)" == "Running" ]; then
  echo -e "\n📊 Pod is running on node:"
  kubectl get pod cluster-test-pod -o jsonpath='{.spec.nodeName}'
  echo ""
  
  echo -e "\n📊 Pod logs (should show ping output if networking works):"
  kubectl logs cluster-test-pod
  
  echo -e "\n📊 To check more logs, run:"
  echo "kubectl logs cluster-test-pod"
else
  echo "❌ Pod is not running. Checking pod events:"
  kubectl describe pod cluster-test-pod
  
  echo -e "\n📊 Checking cluster node status:"
  kubectl get nodes
fi

echo -e "\n✅ Cluster test pod deployment completed."