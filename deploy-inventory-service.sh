#!/bin/bash

# Script to deploy the inventory service
set -e

CLUSTER_NAME="order-system-cluster"
REGION="us-east-1"
ENVIRONMENT=${ENVIRONMENT:-"cloud"}  # Default to cloud, can be overridden with ENVIRONMENT=local
DB_HOST=${DB_HOST:-"terraform-20250721141508796600000004.cmw3e40chj7r.us-east-1.rds.amazonaws.com"}
DB_PORT=${DB_PORT:-"5432"}
DB_NAME=${DB_NAME:-"inventorydb"}
DB_USER=${DB_USER:-"inventoryuser"}
DB_PASSWORD=${DB_PASSWORD:-"inventorypass"}
IMAGE_TAG=${IMAGE_TAG:-"latest"}

echo "🚀 Deploying inventory service to EKS cluster: ${CLUSTER_NAME} (Environment: ${ENVIRONMENT})"

# Update kubeconfig for cloud deployment
echo "📝 Updating kubeconfig for cloud deployment..."
aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${REGION} || {
  echo "❌ Failed to update kubeconfig. Make sure AWS CLI is configured correctly."
  exit 1
}

# Create ECR pull secret
echo "🔑 Creating ECR pull secret..."
# Get ECR login token
ECR_TOKEN=$(aws ecr get-login-password --region ${REGION})
# Create the secret in the namespace
kubectl create namespace inventory-service --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret docker-registry aws-registry \
  --docker-server=294417223953.dkr.ecr.us-east-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password="${ECR_TOKEN}" \
  --namespace=inventory-service \
  --dry-run=client -o yaml | kubectl apply -f -

# Create Kubernetes resources directly with kubectl
echo "🔧 Creating Kubernetes resources directly with kubectl..."

# Create namespace
echo "Creating namespace inventory-service..."
kubectl create namespace inventory-service --dry-run=client -o yaml | kubectl apply -f -

# Create service account
echo "Creating service account..."
cat > inventory-service-sa.yaml << EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: inventory-service-sa
  namespace: inventory-service
  labels:
    app: inventory-service
    part-of: inventory-system
EOF
kubectl apply -f inventory-service-sa.yaml

# Create config map with environment-specific settings
echo "Creating config map..."
cat > inventory-service-config.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: inventory-service-config
  namespace: inventory-service
data:
  # Database connection information
  PG_HOST: "${DB_HOST}"
  PG_CONTAINER: "postgres-inventorydb"
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
kubectl apply -f inventory-service-config.yaml

# Create deployment
echo "Creating deployment..."
cat > inventory-service-deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inventory-service
  namespace: inventory-service
  labels:
    app: inventory-service
    version: v1
    part-of: inventory-system
    environment: ${ENVIRONMENT}
  annotations:
    kubernetes.io/description: "Inventory service for managing product inventory"
    kubernetes.io/change-cause: "Deployment of inventory service (${ENVIRONMENT} environment)"
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
  selector:
    matchLabels:
      app: inventory-service
  template:
    metadata:
      labels:
        app: inventory-service
        version: v1
        part-of: inventory-system
        environment: ${ENVIRONMENT}
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/actuator/prometheus"
    spec:
      serviceAccountName: inventory-service-sa
      imagePullSecrets:
      - name: aws-registry
      containers:
      - name: inventory-service
        image: 294417223953.dkr.ecr.us-east-1.amazonaws.com/inventory-service:${IMAGE_TAG}
        imagePullPolicy: Always
        ports:
        - name: http
          containerPort: 8080
        envFrom:
        - configMapRef:
            name: inventory-service-config
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
kubectl apply -f inventory-service-deployment.yaml

# Create service
echo "Creating service..."
cat > inventory-service-service.yaml << EOF
apiVersion: v1
kind: Service
metadata:
  name: inventory-service
  namespace: inventory-service
  labels:
    app: inventory-service
    part-of: inventory-system
    environment: ${ENVIRONMENT}
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    prometheus.io/path: "/actuator/prometheus"
spec:
  selector:
    app: inventory-service
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
kubectl apply -f inventory-service-service.yaml

# Create HPA only for cloud environment
if [ "$ENVIRONMENT" != "local" ]; then
  echo "Creating horizontal pod autoscaler..."
  cat > inventory-service-hpa.yaml << EOF
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: inventory-service-hpa
  namespace: inventory-service
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: inventory-service
  minReplicas: 2
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
EOF
  kubectl apply -f inventory-service-hpa.yaml
fi

# Create ingress
echo "Creating ingress..."
cat > inventory-service-ingress.yaml << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: inventory-service-ingress
  namespace: inventory-service
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
    alb.ingress.kubernetes.io/group.name: inventory-system
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
    alb.ingress.kubernetes.io/tags: Environment=production,Project=inventory-system
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: inventory-service
            port:
              number: 80
EOF
kubectl apply -f inventory-service-ingress.yaml

# Wait for deployment to be ready
echo "⏳ Waiting for deployment to be ready..."
kubectl rollout status deployment/inventory-service -n inventory-service --timeout=300s

# Check service
echo "🔍 Checking inventory service..."
kubectl get service inventory-service -n inventory-service

# Check pods
echo "🔍 Checking inventory service pods..."
kubectl get pods -n inventory-service -l app=inventory-service

# Check ingress
echo "🔍 Checking inventory service ingress..."
kubectl get ingress -n inventory-service

echo "⏳ Waiting for ingress to be provisioned..."
sleep 30

# Get the ingress URL
INGRESS_URL=$(kubectl get ingress -n inventory-service -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')

if [ -n "$INGRESS_URL" ]; then
  echo "✅ Inventory service is now accessible at: http://$INGRESS_URL"
else
  echo "⚠️ Ingress URL not available yet. It may take a few minutes for the ALB to be provisioned."
  echo "Run the following command to check the status:"
  echo "kubectl get ingress -n inventory-service"
fi

# Clean up temporary YAML files
echo "🧹 Cleaning up temporary files..."
rm -f inventory-service-sa.yaml
rm -f inventory-service-config.yaml
rm -f inventory-service-deployment.yaml
rm -f inventory-service-service.yaml
rm -f inventory-service-ingress.yaml
if [ -f inventory-service-hpa.yaml ]; then
  rm -f inventory-service-hpa.yaml
fi

echo "✅ Inventory service deployment completed."