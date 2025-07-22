#!/bin/bash

# Script to check if applications are running correctly
set -e

CLUSTER_NAME="order-system-cluster"
REGION="us-east-1"

echo "🔍 Checking application status in EKS cluster: ${CLUSTER_NAME}"

# Update kubeconfig
echo "📝 Updating kubeconfig..."
aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${REGION}

# Check all namespaces
echo "📊 Namespaces:"
kubectl get namespaces

# Check all deployments
echo -e "\n📊 Deployments across all namespaces:"
kubectl get deployments --all-namespaces

# Check all pods
echo -e "\n📊 Pods across all namespaces:"
kubectl get pods --all-namespaces

# Check all services
echo -e "\n📊 Services across all namespaces:"
kubectl get services --all-namespaces

# Check specific applications
APPLICATIONS=("order-service" "inventory-service" "payment-service")

for app in "${APPLICATIONS[@]}"; do
  echo -e "\n🔍 Checking ${app}..."
  
  # Check if namespace exists
  if kubectl get namespace ${app} &>/dev/null; then
    echo "✅ Namespace ${app} exists"
    
    # Check deployment
    if kubectl get deployment -n ${app} ${app} &>/dev/null; then
      echo "✅ Deployment ${app} exists"
      
      # Check deployment status
      READY=$(kubectl get deployment -n ${app} ${app} -o jsonpath='{.status.readyReplicas}')
      DESIRED=$(kubectl get deployment -n ${app} ${app} -o jsonpath='{.spec.replicas}')
      
      if [ "$READY" == "$DESIRED" ]; then
        echo "✅ Deployment ${app} is ready ($READY/$DESIRED replicas)"
      else
        echo "❌ Deployment ${app} is not ready ($READY/$DESIRED replicas)"
        
        # Check pod status
        echo -e "\n📊 Pod status for ${app}:"
        kubectl get pods -n ${app} -l app=${app}
        
        # Check pod events
        echo -e "\n📊 Events for ${app} pods:"
        POD_NAME=$(kubectl get pods -n ${app} -l app=${app} -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
        if [ -n "$POD_NAME" ]; then
          kubectl describe pod -n ${app} ${POD_NAME}
        else
          echo "No pods found for ${app}"
        fi
        
        # Check logs
        echo -e "\n📊 Logs for ${app} pods:"
        if [ -n "$POD_NAME" ]; then
          kubectl logs -n ${app} ${POD_NAME} --tail=50
        fi
      fi
      
      # Check service
      if kubectl get service -n ${app} ${app} &>/dev/null; then
        echo "✅ Service ${app} exists"
        
        # Check endpoints
        ENDPOINTS=$(kubectl get endpoints -n ${app} ${app} -o jsonpath='{.subsets[0].addresses}')
        if [ -n "$ENDPOINTS" ]; then
          echo "✅ Service ${app} has endpoints"
        else
          echo "❌ Service ${app} has no endpoints"
        fi
      else
        echo "❌ Service ${app} does not exist"
      fi
    else
      echo "❌ Deployment ${app} does not exist"
    fi
  else
    echo "❌ Namespace ${app} does not exist"
  fi
done

echo -e "\n✅ Application check completed."