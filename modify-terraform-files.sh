#!/bin/bash

# Script to modify Terraform files to handle existing resources
set -e

echo "🔧 Modifying Terraform files to handle existing resources..."

# Function to check if a resource exists
resource_exists() {
  local resource_type=$1
  local resource_id=$2
  
  case "$resource_type" in
    "iam_role")
      aws iam get-role --role-name "$resource_id" >/dev/null 2>&1
      return $?
      ;;
    "iam_policy")
      aws iam get-policy --policy-arn "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/$resource_id" >/dev/null 2>&1
      return $?
      ;;
    "security_group")
      aws ec2 describe-security-groups --group-names "$resource_id" >/dev/null 2>&1
      return $?
      ;;
    "kms_alias")
      aws kms list-aliases --query "Aliases[?AliasName=='$resource_id']" --output text | grep -q "$resource_id"
      return $?
      ;;
    "cloudwatch_log_group")
      aws logs describe-log-groups --log-group-name-prefix "$resource_id" --query "logGroups[?logGroupName=='$resource_id']" --output text | grep -q "$resource_id"
      return $?
      ;;
    *)
      echo "Unknown resource type: $resource_type"
      return 1
      ;;
  esac
}

# Create a temporary directory for modified files
mkdir -p terraform-modified

# Modify the API Gateway role in api-sfn/main.tf
if resource_exists "iam_role" "apigateway-stepfunctions-role"; then
  echo "API Gateway role already exists, creating data source instead of resource"
  cat > terraform-modified/api-sfn-main.tf << EOF
# Use data source for existing API Gateway role
data "aws_iam_role" "apigw_sfn_role" {
  name = "apigateway-stepfunctions-role"
}

# Use the data source in the rest of the module
locals {
  apigw_sfn_role_arn = data.aws_iam_role.apigw_sfn_role.arn
}
EOF
fi

# Modify the VPC CNI policy in eks/main.tf
if resource_exists "iam_policy" "order-system-cluster-vpc-cni-custom"; then
  echo "VPC CNI policy already exists, creating data source instead of resource"
  cat > terraform-modified/eks-main.tf << EOF
# Use data source for existing VPC CNI policy
data "aws_iam_policy" "vpc_cni_custom" {
  name = "order-system-cluster-vpc-cni-custom"
}

# Use the data source in the rest of the module
locals {
  vpc_cni_custom_arn = data.aws_iam_policy.vpc_cni_custom.arn
}
EOF
fi

# Modify the Step Functions role in iam/main.tf
if resource_exists "iam_role" "order-saga-sfn-role"; then
  echo "Step Functions role already exists, creating data source instead of resource"
  cat > terraform-modified/iam-main.tf << EOF
# Use data source for existing Step Functions role
data "aws_iam_role" "sfn_role" {
  name = "order-saga-sfn-role"
}

# Use the data source in the rest of the module
locals {
  sfn_role_arn = data.aws_iam_role.sfn_role.arn
}
EOF
fi

# Modify the Lambda execution role in iam/main.tf
if resource_exists "iam_role" "lambda_exec_role"; then
  echo "Lambda execution role already exists, creating data source instead of resource"
  cat > terraform-modified/iam-lambda-main.tf << EOF
# Use data source for existing Lambda execution role
data "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"
}

# Use the data source in the rest of the module
locals {
  lambda_exec_role_arn = data.aws_iam_role.lambda_exec_role.arn
}
EOF
fi

# Modify the security group in network/main.tf
if resource_exists "security_group" "postgresql-sg"; then
  echo "Security group already exists, creating data source instead of resource"
  cat > terraform-modified/network-main.tf << EOF
# Use data source for existing security group
data "aws_security_group" "postgresql_sg" {
  name = "postgresql-sg"
  vpc_id = local.vpc_id
}

# Use the data source in the rest of the module
locals {
  postgresql_sg_id = data.aws_security_group.postgresql_sg.id
}
EOF
fi

# Modify the KMS alias in eks/main.tf
if resource_exists "kms_alias" "alias/eks/order-system-cluster"; then
  echo "KMS alias already exists, creating data source instead of resource"
  cat > terraform-modified/eks-kms-main.tf << EOF
# Use data source for existing KMS alias
data "aws_kms_alias" "eks_cluster" {
  name = "alias/eks/order-system-cluster"
}

# Use the data source in the rest of the module
locals {
  eks_cluster_kms_key_id = data.aws_kms_alias.eks_cluster.target_key_id
}
EOF
fi

# Modify the CloudWatch log group in eks/main.tf
if resource_exists "cloudwatch_log_group" "/aws/eks/order-system-cluster/cluster"; then
  echo "CloudWatch log group already exists, creating data source instead of resource"
  cat > terraform-modified/eks-cloudwatch-main.tf << EOF
# Use data source for existing CloudWatch log group
data "aws_cloudwatch_log_group" "eks_cluster" {
  name = "/aws/eks/order-system-cluster/cluster"
}

# Use the data source in the rest of the module
locals {
  eks_cluster_log_group_name = data.aws_cloudwatch_log_group.eks_cluster.name
}
EOF
fi

echo "✅ Terraform files modified successfully."
echo "The modified files are in the terraform-modified directory."
echo "You can use these files to update your Terraform configuration."