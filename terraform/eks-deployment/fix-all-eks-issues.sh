#!/bin/bash

# Script to fix all EKS issues (VPC configuration and CNI)
set -e

CLUSTER_NAME="order-system-cluster"
REGION="us-east-1"

echo "🚀 Starting comprehensive EKS fix..."

# Step 1: Fix VPC configuration
echo "🔧 Step 1: Fixing VPC configuration..."

# Create a backup of the current state
echo "📦 Creating backup of current state..."
cp terraform.tfstate terraform.tfstate.bak.$(date +%Y%m%d%H%M%S)

# Remove the problematic resources from the state
echo "🗑️ Removing problematic resources from state..."
docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace hashicorp/terraform:latest state rm module.network.aws_vpc.this || true
docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace hashicorp/terraform:latest state rm module.network.aws_subnet.public || true
docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace hashicorp/terraform:latest state rm module.network.aws_subnet.private || true
docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace hashicorp/terraform:latest state rm module.network.aws_subnet.db || true
docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace hashicorp/terraform:latest state rm module.network.aws_db_subnet_group.order_db_subnet_group || true
docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace hashicorp/terraform:latest state rm module.network.aws_db_subnet_group.inventory_db_subnet_group || true

# Import the existing resources
echo "📥 Importing existing VPC..."
docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace hashicorp/terraform:latest import module.network.data.aws_vpc.existing vpc-024c0c2f1ea047c09 || true

echo "📥 Importing existing DB subnet group..."
docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace hashicorp/terraform:latest import module.network.data.aws_db_subnet_group.db_subnet_group order-system-db-subnet-group || true

# Step 2: Apply the EKS module changes for CNI fix
echo "🔧 Step 2: Applying EKS module changes for CNI fix..."
docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace hashicorp/terraform:latest apply -target=module.eks -auto-approve

# Step 3: Fix CNI issues on the cluster
echo "🔧 Step 3: Fixing CNI issues on the cluster..."

# Update kubeconfig
echo "📝 Updating kubeconfig..."
aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${REGION}

# Check if the node role has the required policies
echo "🔍 Checking node IAM role policies..."

# Get the latest nodegroup name
NODEGROUP_NAME=$(aws eks list-nodegroups --cluster-name ${CLUSTER_NAME} --query 'nodegroups[-1]' --output text)
echo "Using nodegroup: ${NODEGROUP_NAME}"

# Get the full node role ARN
NODE_ROLE_ARN=$(aws eks describe-nodegroup --cluster-name ${CLUSTER_NAME} --nodegroup-name ${NODEGROUP_NAME} --query 'nodegroup.nodeRole' --output text)
echo "Node role ARN: ${NODE_ROLE_ARN}"

# Extract just the role name from the ARN
NODE_ROLE=$(echo ${NODE_ROLE_ARN} | awk -F/ '{print $2}')
echo "Node role name: ${NODE_ROLE}"

echo "Checking for required policies..."
aws iam list-attached-role-policies --role-name ${NODE_ROLE} --query 'AttachedPolicies[].PolicyName'

# Attach required policies if missing
echo "Ensuring all required policies are attached..."
aws iam attach-role-policy --role-name ${NODE_ROLE} --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy || true
aws iam attach-role-policy --role-name ${NODE_ROLE} --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy || true
aws iam attach-role-policy --role-name ${NODE_ROLE} --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly || true

# Check if the aws-node pods are running
echo "🔍 Checking aws-node pods..."
kubectl get pods -n kube-system -l k8s-app=aws-node

# Restart the aws-node pods
echo "🔄 Restarting aws-node pods..."
kubectl delete pods -n kube-system -l k8s-app=aws-node

# Wait for the pods to restart
echo "⏳ Waiting for aws-node pods to restart..."
sleep 30

# Check the status of the aws-node pods
echo "🔍 Checking aws-node pods status..."
kubectl get pods -n kube-system -l k8s-app=aws-node

# Check node status
echo "🔍 Checking node status..."
kubectl get nodes

echo "✅ All fixes applied. If there are still issues, you may need to run a full terraform apply:"
echo "docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace hashicorp/terraform:latest apply -var-file=terraform.tfvars"