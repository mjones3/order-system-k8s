# Getting the ALB Endpoints for the Order, Inventory, and Payment Services

This document explains how to get the ALB endpoints for the order, inventory, and payment services.

## Prerequisites

- AWS CLI configured with appropriate permissions
- kubectl configured to access your EKS cluster
- Docker installed (for running Terraform commands)

## Steps to Get the ALB Endpoint

1. **Check the ingress status**:

   For the order service:
   ```bash
   kubectl get ingress -n order-service
   ```

   For the inventory service:
   ```bash
   kubectl get ingress -n inventory-service
   ```

   For the payment service:
   ```bash
   kubectl get ingress -n payment-service
   ```

   This will show you the status of the ingress resources and the hostnames of the ALBs if they're ready.

2. **Get the URLs directly from Terraform outputs**:

   For the order service:
   ```bash
   cd terraform/eks-deployment
   docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace hashicorp/terraform:latest output order_service_url
   ```

   For the inventory service:
   ```bash
   cd terraform/eks-deployment
   docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace hashicorp/terraform:latest output inventory_service_url
   ```

   For the payment service:
   ```bash
   cd terraform/eks-deployment
   docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace hashicorp/terraform:latest output payment_service_url
   ```

   These commands will output the full URLs to access the services.

3. **If the ALB is still provisioning**, you might see that the hostname is not available yet. ALB provisioning can take 5-10 minutes. In this case:
   - Wait a few minutes
   - Run the `kubectl get ingress` command again to check the status

## Troubleshooting

If you're having issues with the ALB endpoint, you can try the following:

1. **Check the AWS Load Balancer Controller logs**:

   ```bash
   kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
   ```

2. **Ensure public subnets are properly tagged**:

   ```bash
   aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-024c0c2f1ea047c09" "Name=tag:Type,Values=public" --query "Subnets[*].[SubnetId,Tags[?Key=='kubernetes.io/role/elb'].Value]" --output text
   ```

   Each public subnet should have the tag `kubernetes.io/role/elb` with value `1`.

3. **Run the deploy-alb.sh script**:

   ```bash
   ./deploy-alb.sh
   ```

   This script will:
   - Tag the public subnets for the ALB controller
   - Create a new public subnet if needed
   - Restart the AWS Load Balancer Controller
   - Apply the order service ingress

## Current ALB Endpoints

### Order Service
The current ALB endpoint for the order service is:

```
k8s-ordersystem-e12bb1ac9f-1090053202.us-east-1.elb.amazonaws.com
```

### Inventory Service
Once deployed, you can get the ALB endpoint for the inventory service using:

```bash
kubectl get ingress -n inventory-service -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'
```

### Payment Service
Once deployed, you can get the ALB endpoint for the payment service using:

```bash
kubectl get ingress -n payment-service -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'
```

You can access your services using these URLs. It might take a few minutes for the DNS to propagate and for the health checks to pass before the services are fully accessible.