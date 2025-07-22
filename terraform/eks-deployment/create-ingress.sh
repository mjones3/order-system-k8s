#!/bin/bash

# Script to create an ALB ingress for the order service using kubectl
set -e

CLUSTER_NAME="order-system-cluster"
REGION="us-east-1"

echo "🚀 Creating ALB ingress for order service..."

# Update kubeconfig
echo "📝 Updating kubeconfig..."
aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${REGION}

# Create ingress resource
echo "🔧 Creating ingress resource..."
cat > order-service-ingress.yaml << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: order-service-ingress
  namespace: order-service
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/healthcheck-path: /actuator/health
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: '15'
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: '5'
    alb.ingress.kubernetes.io/success-codes: '200'
    alb.ingress.kubernetes.io/healthy-threshold-count: '2'
    alb.ingress.kubernetes.io/unhealthy-threshold-count: '2'
    alb.ingress.kubernetes.io/group.name: order-system
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/ssl-redirect: '443'
    alb.ingress.kubernetes.io/tags: Environment=production,Project=order-system
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: order-service
            port:
              number: 80
EOF

kubectl apply -f order-service-ingress.yaml

# Wait for the ingress to be provisioned
echo "⏳ Waiting for ALB ingress to be provisioned (this may take a few minutes)..."
sleep 30

# Get the ingress hostname
INGRESS_HOSTNAME=$(kubectl get ingress -n order-service order-service-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

if [ -z "$INGRESS_HOSTNAME" ]; then
  echo "⚠️ Ingress hostname not available yet. It may take a few minutes for the ALB to be provisioned."
  echo "Run the following command to check the status:"
  echo "kubectl get ingress -n order-service"
else
  echo "✅ Order service is now accessible at: http://$INGRESS_HOSTNAME"
  echo "You can make API requests to this endpoint, for example:"
  echo "curl -X GET http://$INGRESS_HOSTNAME/actuator/health"
fi

# Clean up
rm -f order-service-ingress.yaml