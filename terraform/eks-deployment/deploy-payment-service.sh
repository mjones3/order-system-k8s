#!/bin/bash

# Script to deploy the payment service
set -e

CLUSTER_NAME="order-system-cluster"
REGION="us-east-1"
ENVIRONMENT=${ENVIRONMENT:-"cloud"}  # Default to cloud, can be overridden with ENVIRONMENT=local
DB_HOST=${DB_HOST:-"terraform-20250721141508798300000005.cmw3e40chj7r.us-east-1.rds.amazonaws.com"}
DB_PORT=${DB_PORT:-"5432"}
DB_NAME=${DB_NAME:-"paymentdb"}
DB_USER=${DB_USER:-"paymentuser"}
DB_PASSWORD=${DB_PASSWORD:-"password123"}
IMAGE_TAG=${IMAGE_TAG:-"latest"}

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to check if we're running in a CI environment
is_ci_environment() {
  [ -n "${CI}" ] || [ -n "${GITHUB_ACTIONS}" ] || [ -n "${JENKINS_URL}" ]
}

# Function to check database connectivity
check_db_connectivity() {
  local db_host=$1
  local db_port=$2
  local db_name=$3
  local db_user=$4
  local db_pass=$5
  
  echo "🔍 Checking database connectivity to ${db_host}:${db_port}/${db_name}..."
  
  if command_exists psql; then
    PGPASSWORD="${db_pass}" psql -h "${db_host}" -p "${db_port}" -U "${db_user}" -d "${db_name}" -c "SELECT 1" >/dev/null 2>&1
    return $?
  else
    # Try with kubectl and a temporary pod if psql is not available
    echo "psql not found, using kubectl to check database connectivity..."
    
    # Create a temporary pod to check database connectivity
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: db-connectivity-check
  namespace: payment-service
spec:
  containers:
  - name: postgres-client
    image: postgres:14-alpine
    command: ["sh", "-c", "PGPASSWORD=${db_pass} psql -h ${db_host} -p ${db_port} -U ${db_user} -d ${db_name} -c 'SELECT 1' && echo 'Connection successful' || echo 'Connection failed'"]
  restartPolicy: Never
EOF
    
    # Wait for the pod to complete
    kubectl wait --for=condition=Ready pod/db-connectivity-check -n payment-service --timeout=30s || true
    
    # Check the result
    result=$(kubectl logs db-connectivity-check -n payment-service | grep "Connection successful" || echo "")
    
    # Clean up
    kubectl delete pod db-connectivity-check -n payment-service --wait=false
    
    if [ -n "$result" ]; then
      return 0
    else
      return 1
    fi
  fi
}

echo "🚀 Deploying payment service to EKS cluster: ${CLUSTER_NAME} (Environment: ${ENVIRONMENT})"

if [ "$ENVIRONMENT" = "local" ]; then
  echo "🖥️ Setting up for local development..."
  
  # For local development, we'll use minikube or kind
  if command_exists minikube; then
    echo "Using minikube for local development"
    minikube status || minikube start
    eval $(minikube docker-env)
  elif command_exists kind; then
    echo "Using kind for local development"
    kind get clusters | grep -q "order-system" || kind create cluster --name order-system
  else
    echo "❌ Neither minikube nor kind is installed. Please install one of them for local development."
    exit 1
  fi
else
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
  kubectl create namespace payment-service --dry-run=client -o yaml | kubectl apply -f -
  kubectl create secret docker-registry aws-registry \
    --docker-server=294417223953.dkr.ecr.us-east-1.amazonaws.com \
    --docker-username=AWS \
    --docker-password="${ECR_TOKEN}" \
    --namespace=payment-service \
    --dry-run=client -o yaml | kubectl apply -f -
fi

# Create Kubernetes resources directly with kubectl
echo "🔧 Creating Kubernetes resources directly with kubectl..."

# Create namespace
echo "Creating namespace payment-service..."
kubectl create namespace payment-service --dry-run=client -o yaml | kubectl apply -f -

# Create service account
echo "Creating service account..."
cat > payment-service-sa.yaml << EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: payment-service-sa
  namespace: payment-service
  labels:
    app: payment-service
    part-of: order-system
EOF
kubectl apply -f payment-service-sa.yaml

# Create role
echo "Creating role..."
cat > payment-service-role.yaml << EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: payment-service-role
  namespace: payment-service
rules:
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list", "watch"]
EOF
kubectl apply -f payment-service-role.yaml

# Create role binding
echo "Creating role binding..."
cat > payment-service-role-binding.yaml << EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: payment-service-role-binding
  namespace: payment-service
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: payment-service-role
subjects:
- kind: ServiceAccount
  name: payment-service-sa
  namespace: payment-service
EOF
kubectl apply -f payment-service-role-binding.yaml

# Create config map with environment-specific settings
echo "Creating config map..."
if [ "$ENVIRONMENT" = "local" ]; then
  # Local development config
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
  ENVIRONMENT: "development"
  PG_DB: "${DB_NAME}"
  PG_USER: "${DB_USER}"
  PG_PASS: "${DB_PASSWORD}"
  PG_PORT: "${DB_PORT}"
  
  # Spring Boot specific configuration
  SPRING_PROFILES_ACTIVE: "development"
  SPRING_DATASOURCE_URL: "jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}"
  SPRING_DATASOURCE_USERNAME: "${DB_USER}"
  SPRING_DATASOURCE_PASSWORD: "${DB_PASSWORD}"
  
  # Standard JDBC URL for other frameworks
  DATASOURCE_URL: "jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}"
  
  # Flag to indicate environment
  DEPLOYMENT_ENV: "local"
  
  # Development-specific settings
  SPRING_JPA_HIBERNATE_DDL_AUTO: "update"
  LOGGING_LEVEL_ROOT: "INFO"
  LOGGING_LEVEL_COM_ELUSIVEMEL: "DEBUG"
EOF
else
  # Cloud config
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
fi
kubectl apply -f payment-service-config.yaml

# Check database connectivity before deploying
if ! check_db_connectivity "${DB_HOST}" "${DB_PORT}" "${DB_NAME}" "${DB_USER}" "${DB_PASSWORD}"; then
  echo "❌ Database connectivity check failed. Please check your database configuration."
  echo "If you're sure the database is correctly configured, you can skip this check by setting SKIP_DB_CHECK=true"
  if [ "${SKIP_DB_CHECK}" != "true" ]; then
    exit 1
  else
    echo "⚠️ Skipping database check as requested..."
  fi
fi

# Set the correct image based on environment
if [ "$ENVIRONMENT" = "local" ]; then
  IMAGE="payment-service:${IMAGE_TAG}"
  PULL_POLICY="IfNotPresent"
  IMAGE_PULL_SECRETS=""
else
  IMAGE="294417223953.dkr.ecr.us-east-1.amazonaws.com/payment-service:${IMAGE_TAG}"
  PULL_POLICY="Always"
  IMAGE_PULL_SECRETS="
      imagePullSecrets:
      - name: aws-registry"
fi

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
    part-of: order-system
    environment: ${ENVIRONMENT}
  annotations:
    kubernetes.io/description: "Payment service for processing payments"
    kubernetes.io/change-cause: "Deployment of payment service (${ENVIRONMENT} environment)"
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
        part-of: order-system
        environment: ${ENVIRONMENT}
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/actuator/prometheus"
    spec:
      serviceAccountName: payment-service-sa${IMAGE_PULL_SECRETS}
      containers:
      - name: payment-service
        image: ${IMAGE}
        imagePullPolicy: ${PULL_POLICY}
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
    part-of: order-system
    environment: ${ENVIRONMENT}
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

# Create HPA only for cloud environment
if [ "$ENVIRONMENT" != "local" ]; then
  echo "Creating horizontal pod autoscaler..."
  cat > payment-service-hpa.yaml << EOF
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: payment-service-hpa
  namespace: payment-service
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: payment-service
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
  kubectl apply -f payment-service-hpa.yaml
fi

# Create ingress for payment service
echo "Creating ingress for payment service..."
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
    alb.ingress.kubernetes.io/healthcheck-port: "8080"
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
spec:
  rules:
  - http:
      paths:
      - path: /api/payments
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

# For local development, set up port forwarding
if [ "$ENVIRONMENT" = "local" ]; then
  echo "🔌 Setting up port forwarding for local development..."
  echo "Press Ctrl+C to stop port forwarding when done"
  kubectl port-forward svc/payment-service -n payment-service 8081:80 &
  PORT_FORWARD_PID=$!
  echo "🌐 Payment service is now accessible at http://localhost:8081"
  
  # Wait for user to press Ctrl+C
  trap "kill $PORT_FORWARD_PID; echo 'Port forwarding stopped'" INT
  wait $PORT_FORWARD_PID
else
  # Clean up temporary YAML files
  echo "🧹 Cleaning up temporary files..."
  rm -f payment-service-sa.yaml
  rm -f payment-service-role.yaml
  rm -f payment-service-role-binding.yaml
  rm -f payment-service-config.yaml
  rm -f payment-service-deployment.yaml
  rm -f payment-service-service.yaml
  rm -f payment-service-ingress.yaml
  if [ -f payment-service-hpa.yaml ]; then
    rm -f payment-service-hpa.yaml
  fi

  echo "✅ Payment service deployment completed."
  echo "To check the service endpoint, run:"
  echo "kubectl get ingress payment-service-ingress -n payment-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
  echo "To check the logs, run:"
  echo "kubectl logs -n payment-service -l app=payment-service"
fi