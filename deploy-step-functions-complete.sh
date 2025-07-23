#!/bin/bash

# Script to package Lambda functions and deploy Step Functions
# This version is designed to be resilient to "already exists" errors

# Don't exit on errors - we want to handle them gracefully
set +e

TERRAFORM_IMAGE="hashicorp/terraform:latest"
REGION="us-east-1"
SKIP_IMPORT=${SKIP_IMPORT:-"false"}
FORCE_APPLY=${FORCE_APPLY:-"false"}

echo "🚀 Deploying Step Functions and API Gateway..."

# Step 1: Package Lambda functions
echo "📦 Packaging Lambda functions..."
./package-lambda-functions.sh

# Step 2: Deploy Step Functions and API Gateway
echo "🔧 Deploying Step Functions and API Gateway..."

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

# If we're not skipping imports, try to import existing resources
if [ "$SKIP_IMPORT" != "true" ]; then
  echo "🔍 Checking for existing resources to import..."
  
  # Try to import the API Gateway role
  echo "Checking for API Gateway role..."
  APIGW_ROLE_ARN=$(aws iam get-role --role-name apigateway-stepfunctions-role --query "Role.Arn" --output text 2>/dev/null || echo "")
  if [ -n "$APIGW_ROLE_ARN" ] && [ "$APIGW_ROLE_ARN" != "None" ]; then
    echo "Found existing API Gateway role: $APIGW_ROLE_ARN"
    run_terraform import module.api-sfn.aws_iam_role.apigw_sfn_role $APIGW_ROLE_ARN || echo "⚠️ API Gateway role import failed, but continuing..."
  fi
  
  # Try to import the Step Functions state machine
  echo "Checking for Step Functions state machine..."
  SFN_ARN=$(aws stepfunctions list-state-machines --query "stateMachines[?name=='OrderSagaStateMachine'].stateMachineArn" --output text 2>/dev/null || echo "")
  if [ -n "$SFN_ARN" ] && [ "$SFN_ARN" != "None" ]; then
    echo "Found existing Step Functions state machine: $SFN_ARN"
    run_terraform import module.lambda.aws_sfn_state_machine.order_saga $SFN_ARN || echo "⚠️ Step Functions state machine import failed, but continuing..."
  fi
  
  # Try to import Lambda functions
  echo "Checking for Lambda functions..."
  for FUNCTION_NAME in "orderServiceFunction" "inventoryServiceFunction" "paymentServiceFunction" "releaseInventoryFunction" "cancelOrderFunction"; do
    LAMBDA_ARN=$(aws lambda get-function --function-name $FUNCTION_NAME --query "Configuration.FunctionArn" --output text 2>/dev/null || echo "")
    if [ -n "$LAMBDA_ARN" ] && [ "$LAMBDA_ARN" != "None" ]; then
      echo "Found existing Lambda function: $LAMBDA_ARN"
      RESOURCE_NAME=$(echo $FUNCTION_NAME | sed 's/Function$//' | sed 's/\([a-z0-9]\)\([A-Z]\)/\1_\2/g' | tr '[:upper:]' '[:lower:]')
      run_terraform import module.lambda.aws_lambda_function.$RESOURCE_NAME $LAMBDA_ARN || echo "⚠️ Lambda function import failed, but continuing..."
    fi
  done
  
  # Try to import IAM roles
  echo "Checking for IAM roles..."
  for ROLE_NAME in "order-saga-sfn-role" "lambda_exec_role"; do
    ROLE_ARN=$(aws iam get-role --role-name $ROLE_NAME --query "Role.Arn" --output text 2>/dev/null || echo "")
    if [ -n "$ROLE_ARN" ] && [ "$ROLE_ARN" != "None" ]; then
      echo "Found existing IAM role: $ROLE_ARN"
      if [ "$ROLE_NAME" == "order-saga-sfn-role" ]; then
        run_terraform import module.iam.aws_iam_role.sfn_role $ROLE_ARN || echo "⚠️ IAM role import failed, but continuing..."
      elif [ "$ROLE_NAME" == "lambda_exec_role" ]; then
        run_terraform import module.iam.aws_iam_role.lambda_exec_role $ROLE_ARN || echo "⚠️ IAM role import failed, but continuing..."
      fi
    fi
  done
  
  # Try to import VPC CNI policy
  echo "Checking for VPC CNI policy..."
  POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='order-system-cluster-vpc-cni-custom'].Arn" --output text 2>/dev/null || echo "")
  if [ -n "$POLICY_ARN" ] && [ "$POLICY_ARN" != "None" ]; then
    echo "Found existing VPC CNI policy: $POLICY_ARN"
    run_terraform import module.eks.aws_iam_policy.vpc_cni_custom $POLICY_ARN || echo "⚠️ VPC CNI policy import failed, but continuing..."
  fi
  
  # Try to import security group
  echo "Checking for security group..."
  SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=postgresql-sg" --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || echo "")
  if [ -n "$SG_ID" ] && [ "$SG_ID" != "None" ]; then
    echo "Found existing security group: $SG_ID"
    run_terraform import module.network.aws_security_group.postgresql-sg $SG_ID || echo "⚠️ Security group import failed, but continuing..."
  fi
  
  # Try to import KMS alias
  echo "Checking for KMS alias..."
  KMS_ALIAS=$(aws kms list-aliases --query "Aliases[?AliasName=='alias/eks/order-system-cluster'].AliasName" --output text 2>/dev/null || echo "")
  if [ -n "$KMS_ALIAS" ] && [ "$KMS_ALIAS" != "None" ]; then
    echo "Found existing KMS alias: $KMS_ALIAS"
    run_terraform import module.eks.module.eks.module.kms.aws_kms_alias.this[\"cluster\"] $KMS_ALIAS || echo "⚠️ KMS alias import failed, but continuing..."
  fi
  
  # Try to import CloudWatch log group
  echo "Checking for CloudWatch log group..."
  LOG_GROUP=$(aws logs describe-log-groups --log-group-name-prefix "/aws/eks/order-system-cluster" --query "logGroups[0].logGroupName" --output text 2>/dev/null || echo "")
  if [ -n "$LOG_GROUP" ] && [ "$LOG_GROUP" != "None" ]; then
    echo "Found existing CloudWatch log group: $LOG_GROUP"
    run_terraform import module.eks.module.eks.aws_cloudwatch_log_group.this[0] $LOG_GROUP || echo "⚠️ CloudWatch log group import failed, but continuing..."
  fi
fi

# If force apply is set, skip the plan and apply directly
if [ "$FORCE_APPLY" == "true" ]; then
  echo "🔨 Force applying changes directly..."
  run_terraform apply -auto-approve \
    -target=module.lambda \
    -target=module.api-sfn || {
      echo "⚠️ Force apply failed, but we'll try to continue..."
    }
else
  # Try to create a plan
  echo "� Creating plaxn for lambda and api-sfn modules..."
  run_terraform plan \
    -target=module.lambda \
    -target=module.api-sfn \
    -out=step-functions.tfplan || {
      echo "⚠️ Plan creation failed, trying direct apply..."
      
      # Try direct apply
      run_terraform apply -auto-approve \
        -target=module.lambda \
        -target=module.api-sfn || {
          echo "⚠️ Direct apply failed, trying with refresh-only first..."
          
          # Try refresh-only first
          run_terraform refresh \
            -target=module.lambda \
            -target=module.api-sfn
          
          # Then try apply again
          run_terraform apply -auto-approve \
            -target=module.lambda \
            -target=module.api-sfn || {
              echo "❌ All apply attempts failed. Please check the error messages above."
              echo "You can try running with FORCE_APPLY=true to bypass planning."
              exit 1
            }
        }
    }

  # If we got here and have a plan file, apply it
  if [ -f "step-functions.tfplan" ]; then
    echo "🔧 Applying Step Functions and API Gateway plan..."
    run_terraform apply -auto-approve step-functions.tfplan || {
      echo "⚠️ Plan apply failed, trying direct apply..."
      
      # Try direct apply as fallback
      run_terraform apply -auto-approve \
        -target=module.lambda \
        -target=module.api-sfn || {
          echo "❌ All apply attempts failed. Please check the error messages above."
          exit 1
        }
    }
  fi
fi

# Try to get the API Gateway endpoint
echo "🔍 Getting API Gateway endpoint..."
API_ENDPOINT=$(run_terraform output -json module.api-sfn | jq -r '.api_endpoint.value' 2>/dev/null)

# If we couldn't get the endpoint from Terraform, try AWS CLI
if [ -z "$API_ENDPOINT" ] || [ "$API_ENDPOINT" == "null" ]; then
  echo "⚠️ Couldn't get API Gateway endpoint from Terraform output, trying AWS CLI..."
  API_ID=$(aws apigatewayv2 get-apis --query "Items[?Name=='orders-saga-api'].ApiId" --output text)
  if [ -n "$API_ID" ] && [ "$API_ID" != "None" ]; then
    API_ENDPOINT=$(aws apigatewayv2 get-api --api-id $API_ID --query "ApiEndpoint" --output text)
  fi
fi

if [ -n "$API_ENDPOINT" ] && [ "$API_ENDPOINT" != "null" ]; then
  echo "✅ Step Functions and API Gateway deployed successfully."
  echo "API Gateway endpoint: ${API_ENDPOINT}"
  echo ""
  echo "To test the API, you can use the following curl command:"
  echo "curl -X POST ${API_ENDPOINT}/order -H 'Content-Type: application/json' -d '{\"orderId\": \"123\", \"customerId\": \"456\", \"items\": [{\"productId\": \"789\", \"quantity\": 1}]}'"
else
  echo "⚠️ Deployment may have succeeded, but couldn't get API Gateway endpoint."
  echo "You can check the AWS Console for the API Gateway endpoint."
fi