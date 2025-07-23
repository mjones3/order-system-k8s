#!/bin/bash

# Script to deploy the ALB controller and configure it properly
set -e

echo "🚀 Deploying ALB controller and configuring it properly..."

# Navigate to terraform/eks-deployment directory
cd terraform/eks-deployment

# Initialize Terraform
echo "📝 Initializing Terraform..."
docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace hashicorp/terraform:latest init

# Tag public subnets for ALB controller
echo "🏷️ Tagging public subnets for ALB controller..."
PUBLIC_SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-024c0c2f1ea047c09" "Name=tag:Type,Values=public" --query "Subnets[*].SubnetId" --output text)
for subnet in $PUBLIC_SUBNETS; do
  echo "Tagging subnet $subnet with kubernetes.io/role/elb=1"
  aws ec2 create-tags --resources $subnet --tags Key=kubernetes.io/role/elb,Value=1
done

# Tag private subnets for internal ALB controller
echo "🏷️ Tagging private subnets for internal ALB controller..."
PRIVATE_SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-024c0c2f1ea047c09" "Name=tag:Type,Values=private" --query "Subnets[*].SubnetId" --output text)
for subnet in $PRIVATE_SUBNETS; do
  echo "Tagging subnet $subnet with kubernetes.io/role/internal-elb=1"
  aws ec2 create-tags --resources $subnet --tags Key=kubernetes.io/role/internal-elb,Value=1
done

# Ensure we have at least 2 public subnets in different AZs
echo "🔍 Checking if we have at least 2 public subnets in different AZs..."
PUBLIC_SUBNET_COUNT=$(echo "$PUBLIC_SUBNETS" | wc -w)
if [ "$PUBLIC_SUBNET_COUNT" -lt 2 ]; then
  echo "⚠️ Less than 2 public subnets found. Creating a new public subnet..."
  
  # Get VPC ID
  VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:project,Values=order-system" --query "Vpcs[0].VpcId" --output text)
  
  # Get CIDR block for new subnet
  VPC_CIDR=$(aws ec2 describe-vpcs --vpc-ids $VPC_ID --query "Vpcs[0].CidrBlock" --output text)
  NEW_SUBNET_CIDR="172.2.2.0/24"  # Adjust as needed
  
  # Get available AZ that doesn't have a public subnet
  USED_AZS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Type,Values=public" --query "Subnets[*].AvailabilityZone" --output text)
  ALL_AZS=$(aws ec2 describe-availability-zones --query "AvailabilityZones[?State=='available'].ZoneName" --output text)
  
  for az in $ALL_AZS; do
    if [[ ! "$USED_AZS" =~ "$az" ]]; then
      AVAILABLE_AZ=$az
      break
    fi
  done
  
  if [ -z "$AVAILABLE_AZ" ]; then
    AVAILABLE_AZ=$(echo "$ALL_AZS" | awk '{print $1}')
  fi
  
  echo "Creating new public subnet in $AVAILABLE_AZ with CIDR $NEW_SUBNET_CIDR"
  NEW_SUBNET_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $NEW_SUBNET_CIDR --availability-zone $AVAILABLE_AZ --query "Subnet.SubnetId" --output text)
  
  # Tag the new subnet
  aws ec2 create-tags --resources $NEW_SUBNET_ID --tags Key=Type,Value=public Key=kubernetes.io/role/elb,Value=1 Key=Name,Value=public-$AVAILABLE_AZ
  
  # Get route table for public subnets
  PUBLIC_RT=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" "Name=route.gateway-id,Values=*" --query "RouteTables[0].RouteTableId" --output text)
  
  # Associate the new subnet with the public route table
  aws ec2 associate-route-table --subnet-id $NEW_SUBNET_ID --route-table-id $PUBLIC_RT
  
  # Enable auto-assign public IP
  aws ec2 modify-subnet-attribute --subnet-id $NEW_SUBNET_ID --map-public-ip-on-launch
  
  echo "✅ Created new public subnet $NEW_SUBNET_ID in $AVAILABLE_AZ"
fi

# Restart the AWS Load Balancer Controller
echo "🔄 Restarting the AWS Load Balancer Controller..."
kubectl rollout restart deployment aws-load-balancer-controller -n kube-system
kubectl rollout status deployment aws-load-balancer-controller -n kube-system

# Apply the order service ingress
echo "📝 Applying the order service ingress..."
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
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: "15"
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: "5"
    alb.ingress.kubernetes.io/success-codes: "200"
    alb.ingress.kubernetes.io/healthy-threshold-count: "2"
    alb.ingress.kubernetes.io/unhealthy-threshold-count: "2"
    alb.ingress.kubernetes.io/group.name: order-system
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
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

# Apply the inventory service ingress
echo "📝 Applying the inventory service ingress..."
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

# Apply the payment service ingress
echo "📝 Applying the payment service ingress..."
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

echo "⏳ Waiting for ingresses to be provisioned..."
sleep 30

# Get the order service ingress URL
ORDER_INGRESS_URL=$(kubectl get ingress -n order-service -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')

if [ -n "$ORDER_INGRESS_URL" ]; then
  echo "✅ Order service is now accessible at: http://$ORDER_INGRESS_URL"
else
  echo "⚠️ Order service ingress URL not available yet. It may take a few minutes for the ALB to be provisioned."
  echo "Run the following command to check the status:"
  echo "kubectl get ingress -n order-service"
fi

# Get the inventory service ingress URL
INVENTORY_INGRESS_URL=$(kubectl get ingress -n inventory-service -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')

if [ -n "$INVENTORY_INGRESS_URL" ]; then
  echo "✅ Inventory service is now accessible at: http://$INVENTORY_INGRESS_URL"
else
  echo "⚠️ Inventory service ingress URL not available yet. It may take a few minutes for the ALB to be provisioned."
  echo "Run the following command to check the status:"
  echo "kubectl get ingress -n inventory-service"
fi

# Get the payment service ingress URL
PAYMENT_INGRESS_URL=$(kubectl get ingress -n payment-service -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')

if [ -n "$PAYMENT_INGRESS_URL" ]; then
  echo "✅ Payment service is now accessible at: http://$PAYMENT_INGRESS_URL"
else
  echo "⚠️ Payment service ingress URL not available yet. It may take a few minutes for the ALB to be provisioned."
  echo "Run the following command to check the status:"
  echo "kubectl get ingress -n payment-service"
fi

echo "✅ Deployment completed!"