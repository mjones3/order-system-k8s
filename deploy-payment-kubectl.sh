#!/bin/bash

# Script to deploy the payment service using kubectl directly
set -e

CLUSTER_NAME="order-system-cluster"
REGION="us-east-1"
DB_HOST="terraform-20250721141508798300000005.cmw3e40chj7r.us-east-1.rds.amazonaws.com"
DB_PORT="5432"
DB_NAME="paymentdb"
DB_USER="paymentuser"
DB_PASSWORD="password123"
IMAGE_TAG="latest"

echo "🚀 Deploying payment service using kubectl..."

# Update kubeconfig
echo "📝 Updating kubeconfig..."
aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${REGION}

# Create namespace
echo "Creating namespace payment-service..."
kubectl create namespace payment-service --dry-run=client -o yaml | kubectl apply -f -

# Create ConfigMap
echo "Creating ConfigMap..."
cat > payment-service-config.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: payment-service-config
  namespace: payment-service
data:
  # Database connection information
  PG_HOST: "${DB_HOST}"
  PG_CONTAINER: "postgres-paymentdb"
  DATASOURCE_PORT: "${DB_PORT}"
  ENVIRONMENT: "production"
  PG_DB: "${DB_NAME}"
  PG_USER: "${DB_USER}"
  PG_PASS: "${DB_PASSWORD}"
  PG_PORT: "${DB_PORT}"
  
  # Spring Boot specific configuration
  SPRING_PROFILES_ACTIVE: "production"
  SPRING_DATASOURCE_URL: "jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}"
  SPRING_DATASOURCE_USERNAME: "${DB_USER}"
  SPRING_DATASOURCE_PASSWORD: "${DB_PASSWORD}"
  
  # Standard JDBC URL for other frameworks
  DATASOURCE_URL: "jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}"
  
  # Flag to indicate environment
  DEPLOYMENT_ENV: "cloud"
EOF
kubectl apply -f payment-service-config.yaml

# Create deployment
echo "Creating deployment..."
cat > payment-service-deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-service
  namespace: payment-service
  labels:
    app: payment-service
    version: v1
    part-of: payment-system
  annotations:
    kubernetes.io/description: "Payment service for processing payments"
    kubernetes.io/change-cause: "Initial deployment of payment service"
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
  selector:
    matchLabels:
      app: payment-service
  template:
    metadata:
      labels:
        app: payment-service
        version: v1
        part-of: payment-system
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/actuator/prometheus"
    spec:
      containers:
      - name: payment-service
        image: 294417223953.dkr.ecr.us-east-1.amazonaws.com/payment-service:${IMAGE_TAG}
        imagePullPolicy: Always
        ports:
        - name: http
          containerPort: 8080
        envFrom:
        - configMapRef:
            name: payment-service-config
        env:
        - name: SERVER_PORT
          value: "8080"
        - name: JAVA_OPTS
          value: "-Xms256m -Xmx512m -XX:+UseG1GC"
        resources:
          limits:
            cpu: "1"
            memory: "1Gi"
          requests:
            cpu: "500m"
            memory: "512Mi"
        livenessProbe:
          httpGet:
            path: /actuator/health/liveness
            port: 8080
            httpHeaders:
            - name: Accept
              value: application/json
          initialDelaySeconds: 60
          periodSeconds: 15
          timeoutSeconds: 5
          failureThreshold: 3
          successThreshold: 1
        readinessProbe:
          httpGet:
            path: /actuator/health/readiness
            port: 8080
            httpHeaders:
            - name: Accept
              value: application/json
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 3
          failureThreshold: 3
          successThreshold: 1
EOF
kubectl apply -f payment-service-deployment.yaml

# Create service
echo "Creating service..."
cat > payment-service-service.yaml << EOF
apiVersion: v1
kind: Service
metadata:
  name: payment-service
  namespace: payment-service
  labels:
    app: payment-service
    part-of: payment-system
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    prometheus.io/path: "/actuator/prometheus"
spec:
  selector:
    app: payment-service
  ports:
  - name: http
    port: 80
    targetPort: 8080
    protocol: TCP
  - name: health
    port: 8081
    targetPort: 8080
    protocol: TCP
  type: ClusterIP
  sessionAffinity: ClientIP
EOF
kubectl apply -f payment-service-service.yaml

# Create ingress
echo "Creating ingress..."
cat > payment-service-ingress.yaml << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: payment-service-ingress
  namespace: payment-service
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/healthcheck-path: /actuator/health
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: "15"
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: "5"
    alb.ingress.kubernetes.io/success-codes: "200"
    alb.ingress.kubernetes.io/healthy-threshold-count: "2"
    alb.ingress.kubernetes.io/unhealthy-threshold-count: "2"
    alb.ingress.kubernetes.io/group.name: payment-system
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
    alb.ingress.kubernetes.io/tags: Environment=production,Project=payment-system
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: payment-service
            port:
              number: 80
EOF
kubectl apply -f payment-service-ingress.yaml

# Wait for deployment to be ready
echo "⏳ Waiting for deployment to be ready..."
kubectl rollout status deployment/payment-service -n payment-service --timeout=300s

# Check service
echo "🔍 Checking payment service..."
kubectl get service payment-service -n payment-service

# Check pods
echo "🔍 Checking payment service pods..."
kubectl get pods -n payment-service -l app=payment-service

# Check ingress
echo "🔍 Checking payment service ingress..."
kubectl get ingress -n payment-service

echo "⏳ Waiting for ingress to be provisioned..."
sleep 30

# Get the ingress URL
INGRESS_URL=$(kubectl get ingress -n payment-service -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')

if [ -n "$INGRESS_URL" ]; then
  echo "✅ Payment service is now accessible at: http://$INGRESS_URL"
else
  echo "⚠️ Ingress URL not available yet. It may take a few minutes for the ALB to be provisioned."
  echo "Run the following command to check the status:"
  echo "kubectl get ingress -n payment-service"
fi

# Clean up temporary YAML files
echo "🧹 Cleaning up temporary files..."
rm -f payment-service-config.yaml
rm -f payment-service-deployment.yaml
rm -f payment-service-service.yaml
rm -f payment-service-ingress.yaml

echo "✅ Payment service deployment completed."