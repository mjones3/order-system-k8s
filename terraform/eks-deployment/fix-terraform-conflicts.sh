#!/bin/bash

# Script to fix Terraform conflicts by importing existing resources
set -e

REGION="us-east-1"
TERRAFORM_IMAGE="hashicorp/terraform:latest"

echo "🔧 Fixing Terraform conflicts by importing existing resources"

# Set AWS region
export AWS_REGION=${REGION}

# Navigate to the Terraform directory
cd "$(dirname "$0")"

# Function to run Terraform commands via Docker
run_terraform() {
  docker run --rm -it \
    -v $(pwd):/workspace \
    -v ~/.aws:/root/.aws \
    -w /workspace \
    ${TERRAFORM_IMAGE} $@
}

# Initialize Terraform
echo "📝 Initializing Terraform..."
run_terraform init

echo "🔍 Checking for existing resources to import..."

# Check and import IAM Policy
echo "Checking for IAM Policy 'order-system-cluster-vpc-cni-custom'..."
POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='order-system-cluster-vpc-cni-custom'].Arn" --output text 2>/dev/null || echo "")
if [ "$POLICY_ARN" != "None" ] && [ "$POLICY_ARN" != "" ]; then
  echo "Found existing IAM policy: $POLICY_ARN"
  echo "Importing IAM policy into Terraform state..."
  run_terraform import module.eks.aws_iam_policy.vpc_cni_custom $POLICY_ARN || echo "IAM policy import failed, but continuing..."
else
  echo "IAM Policy not found, no import needed."
fi

# Check and import Security Group
echo "Checking for Security Group 'postgresql-sg'..."
SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=postgresql-sg" --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || echo "")
if [ "$SG_ID" != "None" ] && [ "$SG_ID" != "" ]; then
  echo "Found existing security group: $SG_ID"
  echo "Importing security group into Terraform state..."
  run_terraform import module.network.aws_security_group.postgresql-sg $SG_ID || echo "Security group import failed, but continuing..."
else
  echo "Security Group not found, no import needed."
fi

# Check and import KMS Alias
echo "Checking for KMS Alias 'alias/eks/order-system-cluster'..."
KMS_ALIAS=$(aws kms list-aliases --query "Aliases[?AliasName=='alias/eks/order-system-cluster'].AliasName" --output text 2>/dev/null || echo "")
if [ "$KMS_ALIAS" != "None" ] && [ "$KMS_ALIAS" != "" ]; then
  echo "Found existing KMS alias: $KMS_ALIAS"
  echo "Importing KMS alias into Terraform state..."
  run_terraform import module.eks.module.eks.module.kms.aws_kms_alias.this[\"cluster\"] $KMS_ALIAS || echo "KMS alias import failed, but continuing..."
else
  echo "KMS Alias not found, no import needed."
fi

# Check and import CloudWatch Log Group
echo "Checking for CloudWatch Log Group '/aws/eks/order-system-cluster/cluster'..."
LOG_GROUP=$(aws logs describe-log-groups --log-group-name-prefix "/aws/eks/order-system-cluster" --query "logGroups[0].logGroupName" --output text 2>/dev/null || echo "")
if [ "$LOG_GROUP" != "None" ] && [ "$LOG_GROUP" != "" ]; then
  echo "Found existing CloudWatch log group: $LOG_GROUP"
  echo "Importing CloudWatch log group into Terraform state..."
  run_terraform import module.eks.module.eks.aws_cloudwatch_log_group.this[0] $LOG_GROUP || echo "CloudWatch log group import failed, but continuing..."
else
  echo "CloudWatch Log Group not found, no import needed."
fi

echo "✅ Import process completed."
echo "Now you can run the deployment script with SKIP_IMPORT=true to avoid these checks:"
echo "SKIP_IMPORT=true ./deploy-payment-service-tf.sh"