#!/bin/bash

# Script to fix Step Functions resources by importing existing resources
set -e

TERRAFORM_IMAGE="hashicorp/terraform:latest"
REGION="us-east-1"

echo "🔧 Fixing Step Functions resources by importing existing resources..."

# Navigate to the Terraform directory
cd terraform/eks-deployment

# Function to run Terraform commands via Docker
run_terraform() {
  docker run --rm -it \
    -v $(pwd):/workspace \
    -v ~/.aws:/root/.aws \
    -w /workspace \
    -e AWS_REGION=${REGION} \
    ${TERRAFORM_IMAGE} $@
}

# Initialize Terraform
echo "📝 Initializing Terraform..."
run_terraform init

# Import existing resources
echo "🔍 Checking for existing resources to import..."

# Check if the API Gateway role already exists
APIGW_ROLE_ARN=$(aws iam get-role --role-name apigateway-stepfunctions-role --query "Role.Arn" --output text 2>/dev/null || echo "")
if [ "$APIGW_ROLE_ARN" != "None" ] && [ "$APIGW_ROLE_ARN" != "" ]; then
  echo "Found existing API Gateway role: $APIGW_ROLE_ARN"
  echo "Importing API Gateway role into Terraform state..."
  run_terraform import module.api-sfn.aws_iam_role.apigw_sfn_role $APIGW_ROLE_ARN || echo "API Gateway role import failed, but continuing..."
fi

# Check if the Step Functions state machine already exists
SFN_ARN=$(aws stepfunctions list-state-machines --query "stateMachines[?name=='OrderSagaStateMachine'].stateMachineArn" --output text 2>/dev/null || echo "")
if [ "$SFN_ARN" != "None" ] && [ "$SFN_ARN" != "" ]; then
  echo "Found existing Step Functions state machine: $SFN_ARN"
  echo "Importing Step Functions state machine into Terraform state..."
  run_terraform import module.lambda.aws_sfn_state_machine.order_saga $SFN_ARN || echo "Step Functions state machine import failed, but continuing..."
fi

# Check if Lambda functions already exist
for FUNCTION_NAME in "orderServiceFunction" "inventoryServiceFunction" "paymentServiceFunction" "releaseInventoryFunction" "cancelOrderFunction"; do
  LAMBDA_ARN=$(aws lambda get-function --function-name $FUNCTION_NAME --query "Configuration.FunctionArn" --output text 2>/dev/null || echo "")
  if [ "$LAMBDA_ARN" != "None" ] && [ "$LAMBDA_ARN" != "" ]; then
    echo "Found existing Lambda function: $LAMBDA_ARN"
    echo "Importing Lambda function into Terraform state..."
    RESOURCE_NAME=$(echo $FUNCTION_NAME | sed 's/Function$//' | sed 's/\([a-z0-9]\)\([A-Z]\)/\1_\2/g' | tr '[:upper:]' '[:lower:]')
    run_terraform import module.lambda.aws_lambda_function.$RESOURCE_NAME $LAMBDA_ARN || echo "Lambda function import failed, but continuing..."
  fi
done

# Check if the IAM roles already exist
for ROLE_NAME in "order-saga-sfn-role" "lambda_exec_role"; do
  ROLE_ARN=$(aws iam get-role --role-name $ROLE_NAME --query "Role.Arn" --output text 2>/dev/null || echo "")
  if [ "$ROLE_ARN" != "None" ] && [ "$ROLE_ARN" != "" ]; then
    echo "Found existing IAM role: $ROLE_ARN"
    echo "Importing IAM role into Terraform state..."
    RESOURCE_NAME=$(echo $ROLE_NAME | sed 's/-/_/g')
    if [ "$ROLE_NAME" == "order-saga-sfn-role" ]; then
      run_terraform import module.iam.aws_iam_role.sfn_role $ROLE_ARN || echo "IAM role import failed, but continuing..."
    elif [ "$ROLE_NAME" == "lambda_exec_role" ]; then
      run_terraform import module.iam.aws_iam_role.lambda_exec_role $ROLE_ARN || echo "IAM role import failed, but continuing..."
    fi
  fi
done

# Check if the VPC CNI policy already exists
POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='order-system-cluster-vpc-cni-custom'].Arn" --output text 2>/dev/null || echo "")
if [ "$POLICY_ARN" != "None" ] && [ "$POLICY_ARN" != "" ]; then
  echo "Found existing VPC CNI policy: $POLICY_ARN"
  echo "Importing VPC CNI policy into Terraform state..."
  run_terraform import module.eks.aws_iam_policy.vpc_cni_custom $POLICY_ARN || echo "VPC CNI policy import failed, but continuing..."
fi

# Check if the security group already exists
SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=postgresql-sg" --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || echo "")
if [ "$SG_ID" != "None" ] && [ "$SG_ID" != "" ]; then
  echo "Found existing security group: $SG_ID"
  echo "Importing security group into Terraform state..."
  run_terraform import module.network.aws_security_group.postgresql-sg $SG_ID || echo "Security group import failed, but continuing..."
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

echo "✅ Resource import completed."
echo "Now you can run the deploy-step-functions-complete.sh script to deploy the Step Functions and API Gateway."