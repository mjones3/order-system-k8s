#!/bin/bash

# Script to deploy only the payment service resources with Terraform using Docker
set -e

REGION="us-east-1"
ENVIRONMENT=${ENVIRONMENT:-"cloud"}
SKIP_IMPORT=${SKIP_IMPORT:-"false"}
TERRAFORM_IMAGE="hashicorp/terraform:latest"
TERRAFORM_VARS_FILE=${TERRAFORM_VARS_FILE:-"terraform.tfvars"}

echo "🚀 Deploying payment service resources with Terraform (Environment: ${ENVIRONMENT})"

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

# Always check for existing resources to import
echo "🔍 Checking for existing resources to import..."

# Check if the security group already exists
SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=postgresql-sg" --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || echo "")
if [ "$SG_ID" != "None" ] && [ "$SG_ID" != "" ]; then
  echo "Found existing security group: $SG_ID"
  echo "Importing security group into Terraform state..."
  run_terraform import module.network.aws_security_group.postgresql-sg $SG_ID || echo "Security group import failed, but continuing..."
fi

# Check if the IAM policy already exists
POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='order-system-cluster-vpc-cni-custom'].Arn" --output text 2>/dev/null || echo "")
if [ "$POLICY_ARN" != "None" ] && [ "$POLICY_ARN" != "" ]; then
  echo "Found existing IAM policy: $POLICY_ARN"
  echo "Importing IAM policy into Terraform state..."
  run_terraform import module.eks.aws_iam_policy.vpc_cni_custom $POLICY_ARN || echo "IAM policy import failed, but continuing..."
fi

# Check if the KMS alias already exists
KMS_ALIAS=$(aws kms list-aliases --query "Aliases[?AliasName=='alias/eks/order-system-cluster'].AliasName" --output text 2>/dev/null || echo "")
if [ "$KMS_ALIAS" != "None" ] && [ "$KMS_ALIAS" != "" ]; then
  echo "Found existing KMS alias: $KMS_ALIAS"
  echo "Importing KMS alias into Terraform state..."
  run_terraform import module.eks.module.eks.module.kms.aws_kms_alias.this[\"cluster\"] $KMS_ALIAS || echo "KMS alias import failed, but continuing..."
fi

# Check if the CloudWatch log group already exists
LOG_GROUP=$(aws logs describe-log-groups --log-group-name-prefix "/aws/eks/order-system-cluster" --query "logGroups[0].logGroupName" --output text 2>/dev/null || echo "")
if [ "$LOG_GROUP" != "None" ] && [ "$LOG_GROUP" != "" ]; then
  echo "Found existing CloudWatch log group: $LOG_GROUP"
  echo "Importing CloudWatch log group into Terraform state..."
  run_terraform import module.eks.module.eks.aws_cloudwatch_log_group.this[0] $LOG_GROUP || echo "CloudWatch log group import failed, but continuing..."
fi

# Check if the payment service database already exists
DB_INSTANCE=$(aws rds describe-db-instances --query "DBInstances[?DBName=='paymentdb'].DBInstanceIdentifier" --output text 2>/dev/null || echo "")
if [ "$DB_INSTANCE" != "None" ] && [ "$DB_INSTANCE" != "" ]; then
  echo "Found existing payment service database: $DB_INSTANCE"
  echo "Importing payment service database into Terraform state..."
  run_terraform import module.payment_service_db.aws_db_instance.this $DB_INSTANCE || echo "Payment service database import failed, but continuing..."
fi

# Create a plan file for the payment service modules
echo "📋 Creating plan for payment service modules..."
run_terraform plan \
  -var-file=${TERRAFORM_VARS_FILE} \
  -target=module.payment_service_db \
  -target=module.eks_payment_service \
  -out=payment-service.tfplan || {
    echo "⚠️ Plan creation failed, but we'll try to continue..."
    
    # Try to apply directly with auto-approve
    echo "🔧 Attempting direct apply with auto-approve..."
    run_terraform apply -auto-approve \
      -var-file=${TERRAFORM_VARS_FILE} \
      -target=module.payment_service_db \
      -target=module.eks_payment_service || {
        echo "❌ Direct apply failed. Please check the error messages above."
        exit 1
      }
    
    # Create a new plan after direct apply
    echo "📋 Creating new plan after direct apply..."
    run_terraform plan \
      -var-file=${TERRAFORM_VARS_FILE} \
      -target=module.payment_service_db \
      -target=module.eks_payment_service \
      -out=payment-service.tfplan
  }

# Apply the plan
echo "🔧 Applying payment service plan..."
run_terraform apply -auto-approve payment-service.tfplan

echo "✅ Payment service Terraform deployment completed."
echo "Now run the deploy-payment-service.sh script to deploy the Kubernetes resources."