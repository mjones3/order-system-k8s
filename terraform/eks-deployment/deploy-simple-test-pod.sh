#!/bin/bash

# Script to deploy a simple test pod with tolerations
set -e

echo "🚀 Deploying simple test pod..."

# Get the latest node name
NODE_NAME=$(kubectl get nodes --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}')
echo "🔍 Target node: ${NODE_NAME}"

# Create a simple test pod YAML
cat <<EOF > simple-test-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: simple-test-pod
spec:
  nodeSelector:
    kubernetes.io/hostname: ${NODE_NAME}
  tolerations:
  - key: "node.kubernetes.io/not-ready"
    operator: "Exists"
    effect: "NoSchedule"
  containers:
  - name: alpine
    image: alpine:latest
    command:
      - /bin/sh
      - -c
      - "apk add --no-cache curl iputils && sleep 3600"
EOF

# Delete any existing pod
kubectl delete pod simple-test-pod --ignore-not-found

# Apply the new pod
kubectl apply -f simple-test-pod.yaml

# Wait for the pod to be created
echo "⏳ Waiting for pod to be created..."
sleep 5

# Check pod status
echo -e "\n📊 Pod Status:"
kubectl get pod simple-test-pod -o wide

# Wait for the pod to be running
echo "⏳ Waiting for pod to start running (up to 60 seconds)..."
for i in {1..12}; do
  STATUS=$(kubectl get pod simple-test-pod -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
  if [ "$STATUS" == "Running" ]; then
    echo "✅ Pod is running!"
    break
  fi
  echo "Current status: $STATUS"
  sleep 5
done

# If pod is running, run some basic tests
if [ "$(kubectl get pod simple-test-pod -o jsonpath='{.status.phase}' 2>/dev/null)" == "Running" ]; then
  echo -e "\n📊 Running basic tests..."
  
  echo -e "\n📊 Pod IP:"
  kubectl exec -it simple-test-pod -- ip addr
  
  echo -e "\n📊 Internet connectivity test:"
  kubectl exec -it simple-test-pod -- ping -c 3 8.8.8.8
  
  echo -e "\n📊 DNS resolution test:"
  kubectl exec -it simple-test-pod -- nslookup kubernetes.default.svc.cluster.local
  
  echo -e "\n📊 To run more tests, connect to the pod with:"
  echo "kubectl exec -it simple-test-pod -- /bin/sh"
else
  echo "❌ Pod is not running. Checking pod events:"
  kubectl describe pod simple-test-pod
  
  echo -e "\n📊 Checking node conditions:"
  kubectl describe node ${NODE_NAME}
fi

echo -e "\n✅ Simple test pod deployment completed."