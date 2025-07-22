# EKS Deployment for Order System

This directory contains Terraform configurations to deploy the Order System microservices to Amazon EKS (Elastic Kubernetes Service).

## Architecture Overview

The EKS deployment includes:

- **EKS Cluster**: Managed Kubernetes cluster with auto-scaling node groups
- **Microservices**: Order, Inventory, and Payment services deployed as Kubernetes deployments
- **RDS Databases**: Separate PostgreSQL databases for each service
- **Networking**: VPC with public/private subnets, security groups
- **Auto-scaling**: Horizontal Pod Autoscaler (HPA) for each service
- **Load Balancing**: Kubernetes services with ClusterIP

## Directory Structure

```
terraform/
├── modules/
│   ├── eks/                    # EKS cluster module
│   ├── eks-services/           # EKS service deployment modules
│   │   ├── inventory-service/
│   │   ├── order-service/
│   │   └── payment-service/
│   ├── network/               # VPC and networking (reused)
│   └── services/              # RDS database modules (reused)
├── main-eks.tf               # Main EKS Terraform configuration
├── variables-eks.tf          # EKS-specific variables
├── outputs-eks.tf           # EKS outputs
├── terraform.tfvars.example      # Example variables file
├── deploy-eks.sh            # Deployment script
├── destroy-eks.sh           # Cleanup script
└── README-EKS.md           # This file
```

## Prerequisites

1. **AWS CLI** configured with appropriate permissions
2. **Terraform** >= 1.2.0
3. **kubectl** for Kubernetes management
4. **Docker images** pushed to ECR repositories

### Required AWS Permissions

Your AWS credentials need permissions for:
- EKS cluster management
- EC2 instances and networking
- RDS database creation
- IAM role management
- ECR repository access

## Quick Start

### 1. Configure Variables

Copy the example variables file and update with your values:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
# Docker image URIs from ECR
order_service_image     = "your-account.dkr.ecr.us-east-1.amazonaws.com/order-service:latest"
inventory_service_image = "your-account.dkr.ecr.us-east-1.amazonaws.com/inventory-service:latest"
payment_service_image   = "your-account.dkr.ecr.us-east-1.amazonaws.com/payment-service:latest"

# Database password (use a secure password)
db_password = "your-secure-database-password"

# AWS region
aws_region = "us-east-1"

# Environment
environment = "production"
```

### 2. Deploy Infrastructure

Run the deployment script:

```bash
./deploy-eks.sh
```

This script will:
1. Initialize Terraform
2. Plan the deployment
3. Create VPC, EKS cluster, and RDS databases
4. Deploy the microservices to EKS
5. Verify the deployment

### 3. Access Your Services

After deployment, you can access your services:

```bash
# Get cluster info
kubectl cluster-info

# List all resources
kubectl get all --all-namespaces

# Port forward to access services locally
kubectl port-forward -n order-service service/order-service 8082:80
kubectl port-forward -n inventory-service service/inventory-service 8081:80
kubectl port-forward -n payment-service service/payment-service 8083:80
```

## Manual Deployment

If you prefer manual deployment:

### 1. Initialize Terraform

```bash
terraform init
```

### 2. Plan Infrastructure

```bash
terraform plan -var-file="terraform.tfvars" -out=eks.tfplan
```

### 3. Apply Infrastructure

```bash
terraform apply eks.tfplan
```

### 4. Update kubeconfig

```bash
aws eks update-kubeconfig --name order-system-cluster --region us-east-1
```

## Service Configuration

Each service is deployed with:

- **Namespace**: Separate namespace per service
- **ConfigMap**: Database connection configuration
- **Deployment**: 2 replicas by default
- **Service**: ClusterIP for internal communication
- **HPA**: Auto-scaling based on CPU utilization (70%)

### Resource Limits

Default resource configuration per service:

```yaml
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi
```

### Auto-scaling

Each service has HPA configured:
- **Min replicas**: 2
- **Max replicas**: 10
- **Target CPU**: 70%

## Database Configuration

Each service connects to its own RDS PostgreSQL database:

- **Order Service**: `orderdb` database
- **Inventory Service**: `inventorydb` database  
- **Payment Service**: `paymentdb` database

Databases are deployed in private subnets with security groups allowing access only from EKS nodes.

## Monitoring and Health Checks

Services include:

- **Liveness Probe**: `/actuator/health` endpoint
- **Readiness Probe**: `/actuator/health` endpoint
- **Metrics**: Exposed via Spring Boot Actuator

## Networking

- **VPC**: 172.1.0.0/16
- **Public Subnets**: 172.1.1.0/24, 172.1.2.0/24
- **Private Subnets**: 172.1.3.0/24, 172.1.4.0/24
- **EKS Nodes**: Deployed in private subnets
- **RDS**: Deployed in private subnets

## Security

- EKS nodes in private subnets
- RDS databases in private subnets
- Security groups restrict access
- IAM roles with least privilege
- Secrets managed via Kubernetes ConfigMaps

## Scaling

### Cluster Scaling

EKS managed node group auto-scaling:
- **Min nodes**: 2
- **Max nodes**: 10
- **Desired nodes**: 3
- **Instance type**: t3.medium

### Application Scaling

Horizontal Pod Autoscaler:
- Scales based on CPU utilization
- Min/max replicas configurable per service

## Troubleshooting

### Common Issues

1. **EKS cluster not accessible**
   ```bash
   aws eks update-kubeconfig --name order-system-cluster --region us-east-1
   ```

2. **Pods not starting**
   ```bash
   kubectl describe pod <pod-name> -n <namespace>
   kubectl logs <pod-name> -n <namespace>
   ```

3. **Database connection issues**
   ```bash
   kubectl get configmap -n <namespace>
   kubectl describe configmap <configmap-name> -n <namespace>
   ```

### Useful Commands

```bash
# Check cluster status
kubectl get nodes

# Check service status
kubectl get deployments --all-namespaces
kubectl get services --all-namespaces
kubectl get hpa --all-namespaces

# View logs
kubectl logs -f deployment/<service-name> -n <namespace>

# Scale manually
kubectl scale deployment <service-name> --replicas=5 -n <namespace>
```

## Cleanup

To destroy all resources:

```bash
./destroy-eks.sh
```

Or manually:

```bash
terraform destroy -var-file="terraform.tfvars"
```

## Cost Optimization

- Use Spot instances for non-production workloads
- Right-size RDS instances based on usage
- Enable cluster autoscaler for cost efficiency
- Monitor resource usage and adjust limits

## Next Steps

1. Set up ingress controller for external access
2. Implement service mesh (Istio/Linkerd)
3. Add monitoring (Prometheus/Grafana)
4. Set up CI/CD pipelines
5. Implement GitOps with ArgoCD