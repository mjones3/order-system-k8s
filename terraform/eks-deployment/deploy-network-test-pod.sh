#!/bin/bash

# Script to deploy a network diagnostic pod
set -e

echo "🚀 Deploying network diagnostic pod..."

# Get the latest node name
NODE_NAME=$(kubectl get nodes --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}')
echo "🔍 Target node: ${NODE_NAME}"

# Create a network diagnostic pod YAML
cat <<EOF > network-test-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: network-diagnostic
  labels:
    app: network-diagnostic
spec:
  nodeSelector:
    kubernetes.io/hostname: ${NODE_NAME}
  tolerations:
  - key: "node.kubernetes.io/not-ready"
    operator: "Exists"
    effect: "NoSchedule"
  containers:
  - name: network-tools
    image: nicolaka/netshoot
    command:
      - sleep
      - "3600"
    resources:
      limits:
        memory: "128Mi"
        cpu: "100m"
    securityContext:
      privileged: true
EOF

# Delete any existing pod
kubectl delete pod network-diagnostic --ignore-not-found

# Apply the new pod
kubectl apply -f network-test-pod.yaml

# Wait for the pod to be created
echo "⏳ Waiting for pod to be created..."
sleep 5

# Check pod status
echo -e "\n📊 Pod Status:"
kubectl get pod network-diagnostic -o wide

# Wait for the pod to be running
echo "⏳ Waiting for pod to start running (up to 60 seconds)..."
for i in {1..12}; do
  STATUS=$(kubectl get pod network-diagnostic -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
  if [ "$STATUS" == "Running" ]; then
    echo "✅ Pod is running!"
    break
  fi
  echo "Current status: $STATUS"
  sleep 5
done

# If pod is running, run some network diagnostics
if [ "$(kubectl get pod network-diagnostic -o jsonpath='{.status.phase}' 2>/dev/null)" == "Running" ]; then
  echo -e "\n📊 Running network diagnostics..."
  
  echo -e "\n📊 Pod IP and interfaces:"
  kubectl exec -it network-diagnostic -- ip addr
  
  echo -e "\n📊 DNS resolution test:"
  kubectl exec -it network-diagnostic -- nslookup kubernetes.default.svc.cluster.local
  
  echo -e "\n📊 Internet connectivity test:"
  kubectl exec -it network-diagnostic -- ping -c 3 8.8.8.8
  
  echo -e "\n📊 Route table:"
  kubectl exec -it network-diagnostic -- ip route
  
  echo -e "\n📊 CNI configuration:"
  kubectl exec -it network-diagnostic -- ls -la /etc/cni/net.d/
  kubectl exec -it network-diagnostic -- cat /etc/cni/net.d/*
  
  echo -e "\n📊 Node network namespace information:"
  kubectl exec -it network-diagnostic -- nsenter -t 1 -n ip addr
  
  echo -e "\n📊 To run more diagnostics, connect to the pod with:"
  echo "kubectl exec -it network-diagnostic -- bash"
else
  echo "❌ Pod is not running. Checking pod events:"
  kubectl describe pod network-diagnostic
  
  echo -e "\n📊 Checking node conditions:"
  kubectl describe node ${NODE_NAME}
  
  echo -e "\n📊 Checking CNI pods:"
  kubectl get pods -n kube-system -l k8s-app=aws-node
  
  echo -e "\n📊 Checking CNI logs:"
  CNI_POD=$(kubectl get pods -n kube-system -l k8s-app=aws-node -o jsonpath='{.items[0].metadata.name}')
  kubectl logs -n kube-system ${CNI_POD} --tail=50
fi

echo -e "\n✅ Network diagnostic pod deployment completed."