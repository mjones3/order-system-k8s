#!/bin/bash

# Script to troubleshoot common application issues
set -e

CLUSTER_NAME="order-system-cluster"
REGION="us-east-1"
APP_NAME=$1

if [ -z "$APP_NAME" ]; then
  echo "Usage: $0 <application-name>"
  echo "Example: $0 order-service"
  exit 1
fi

echo "🔧 Troubleshooting ${APP_NAME} in EKS cluster: ${CLUSTER_NAME}"

# Update kubeconfig
echo "📝 Updating kubeconfig..."
aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${REGION}

# Check if namespace exists
if ! kubectl get namespace ${APP_NAME} &>/dev/null; then
  echo "❌ Namespace ${APP_NAME} does not exist"
  exit 1
fi

# Check deployment
if ! kubectl get deployment -n ${APP_NAME} ${APP_NAME} &>/dev/null; then
  echo "❌ Deployment ${APP_NAME} does not exist"
  exit 1
fi

# Check deployment status
READY=$(kubectl get deployment -n ${APP_NAME} ${APP_NAME} -o jsonpath='{.status.readyReplicas}')
DESIRED=$(kubectl get deployment -n ${APP_NAME} ${APP_NAME} -o jsonpath='{.spec.replicas}')

if [ "$READY" != "$DESIRED" ]; then
  echo "❌ Deployment ${APP_NAME} is not ready ($READY/$DESIRED replicas)"
  
  # Check pod status
  echo -e "\n📊 Pod status for ${APP_NAME}:"
  kubectl get pods -n ${APP_NAME} -l app=${APP_NAME}
  
  # Get the first pod that's not ready
  POD_NAME=$(kubectl get pods -n ${APP_NAME} -l app=${APP_NAME} -o jsonpath='{.items[?(@.status.phase!="Running" || @.status.containerStatuses[0].ready==false)].metadata.name}' | awk '{print $1}')
  
  if [ -z "$POD_NAME" ]; then
    POD_NAME=$(kubectl get pods -n ${APP_NAME} -l app=${APP_NAME} -o jsonpath='{.items[0].metadata.name}')
  fi
  
  if [ -n "$POD_NAME" ]; then
    echo -e "\n📊 Pod details for ${POD_NAME}:"
    kubectl describe pod -n ${APP_NAME} ${POD_NAME}
    
    # Check container status
    CONTAINER_STATUS=$(kubectl get pod -n ${APP_NAME} ${POD_NAME} -o jsonpath='{.status.containerStatuses[0].state}')
    echo -e "\n📊 Container status: ${CONTAINER_STATUS}"
    
    # Check if container is waiting
    WAITING_REASON=$(kubectl get pod -n ${APP_NAME} ${POD_NAME} -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}' 2>/dev/null)
    if [ -n "$WAITING_REASON" ]; then
      echo "❌ Container is waiting: ${WAITING_REASON}"
      
      # Check if it's an image pull issue
      if [ "$WAITING_REASON" == "ImagePullBackOff" ] || [ "$WAITING_REASON" == "ErrImagePull" ]; then
        echo "❌ Image pull issue detected"
        
        # Check image details
        IMAGE=$(kubectl get pod -n ${APP_NAME} ${POD_NAME} -o jsonpath='{.spec.containers[0].image}')
        echo "Image: ${IMAGE}"
        
        # Check if image pull secret is configured
        IMAGE_PULL_SECRET=$(kubectl get pod -n ${APP_NAME} ${POD_NAME} -o jsonpath='{.spec.imagePullSecrets[0].name}' 2>/dev/null)
        if [ -n "$IMAGE_PULL_SECRET" ]; then
          echo "Image pull secret: ${IMAGE_PULL_SECRET}"
        else
          echo "No image pull secret configured"
        fi
        
        # Suggest solution
        echo -e "\n🔧 Suggested solution:"
        echo "1. Check if the image exists and is accessible"
        echo "2. Verify image pull secret if using a private registry"
        echo "3. Try pulling the image manually on one of the nodes"
      fi
      
      # Check if it's a crash loop
      if [ "$WAITING_REASON" == "CrashLoopBackOff" ]; then
        echo "❌ Container is crashing"
        
        # Check logs
        echo -e "\n📊 Container logs:"
        kubectl logs -n ${APP_NAME} ${POD_NAME} --previous
        
        # Suggest solution
        echo -e "\n🔧 Suggested solution:"
        echo "1. Check the logs for errors"
        echo "2. Verify environment variables and configuration"
        echo "3. Check resource limits and requests"
      fi
    fi
    
    # Check if container is terminated
    TERMINATED_REASON=$(kubectl get pod -n ${APP_NAME} ${POD_NAME} -o jsonpath='{.status.containerStatuses[0].state.terminated.reason}' 2>/dev/null)
    if [ -n "$TERMINATED_REASON" ]; then
      echo "❌ Container terminated: ${TERMINATED_REASON}"
      
      # Check exit code
      EXIT_CODE=$(kubectl get pod -n ${APP_NAME} ${POD_NAME} -o jsonpath='{.status.containerStatuses[0].state.terminated.exitCode}')
      echo "Exit code: ${EXIT_CODE}"
      
      # Check logs
      echo -e "\n📊 Container logs:"
      kubectl logs -n ${APP_NAME} ${POD_NAME}
    fi
    
    # Check events
    echo -e "\n📊 Events for ${POD_NAME}:"
    kubectl get events -n ${APP_NAME} --field-selector involvedObject.name=${POD_NAME}
    
    # Check logs
    echo -e "\n📊 Logs for ${POD_NAME}:"
    kubectl logs -n ${APP_NAME} ${POD_NAME} --tail=50
  fi
else
  echo "✅ Deployment ${APP_NAME} is ready ($READY/$DESIRED replicas)"
  
  # Check service
  if kubectl get service -n ${APP_NAME} ${APP_NAME} &>/dev/null; then
    echo "✅ Service ${APP_NAME} exists"
    
    # Check endpoints
    ENDPOINTS=$(kubectl get endpoints -n ${APP_NAME} ${APP_NAME} -o jsonpath='{.subsets[0].addresses}')
    if [ -n "$ENDPOINTS" ]; then
      echo "✅ Service ${APP_NAME} has endpoints"
      
      # Test service
      echo -e "\n🔍 Testing service connectivity:"
      kubectl run -i --rm --restart=Never curl-test --image=curlimages/curl -- curl -s http://${APP_NAME}.${APP_NAME}.svc.cluster.local/actuator/health || echo "Failed to test service"
    else
      echo "❌ Service ${APP_NAME} has no endpoints"
    fi
  else
    echo "❌ Service ${APP_NAME} does not exist"
  fi
fi

echo -e "\n✅ Troubleshooting completed."