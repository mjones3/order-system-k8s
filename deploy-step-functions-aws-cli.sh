#!/bin/bash

# Script to deploy Step Functions and API Gateway using AWS CLI directly
# This approach bypasses Terraform completely for resources that already exist

set -e

REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "🚀 Deploying Step Functions and API Gateway using AWS CLI..."

# Step 1: Package Lambda functions
echo "📦 Packaging Lambda functions..."
./package-lambda-functions.sh

# Create directory for Lambda function packages
mkdir -p lambda-packages

# Function to create or update a Lambda function
deploy_lambda_function() {
  local function_name=$1
  local handler=$2
  local zip_file=$3
  local role_arn=$4
  local environment=$5
  
  echo "Deploying Lambda function: $function_name"
  
  # Check if the function already exists
  if aws lambda get-function --function-name "$function_name" >/dev/null 2>&1; then
    echo "Function already exists, updating..."
    aws lambda update-function-code \
      --function-name "$function_name" \
      --zip-file "fileb://$zip_file" \
      --region "$REGION"
    
    aws lambda update-function-configuration \
      --function-name "$function_name" \
      --handler "$handler" \
      --runtime "python3.9" \
      --timeout 30 \
      --memory-size 256 \
      --environment "$environment" \
      --region "$REGION"
  else
    echo "Function doesn't exist, creating..."
    aws lambda create-function \
      --function-name "$function_name" \
      --handler "$handler" \
      --runtime "python3.9" \
      --role "$role_arn" \
      --timeout 30 \
      --memory-size 256 \
      --environment "$environment" \
      --zip-file "fileb://$zip_file" \
      --region "$REGION"
  fi
}

# Function to create or update an IAM role
create_or_update_role() {
  local role_name=$1
  local trust_policy=$2
  local policy_arns=$3
  
  echo "Creating or updating IAM role: $role_name"
  
  # Check if the role already exists
  if aws iam get-role --role-name "$role_name" >/dev/null 2>&1; then
    echo "Role already exists, updating trust policy..."
    aws iam update-assume-role-policy \
      --role-name "$role_name" \
      --policy-document "$trust_policy"
  else
    echo "Role doesn't exist, creating..."
    aws iam create-role \
      --role-name "$role_name" \
      --assume-role-policy "$trust_policy"
  fi
  
  # Attach policies
  for policy_arn in $policy_arns; do
    echo "Attaching policy: $policy_arn"
    aws iam attach-role-policy \
      --role-name "$role_name" \
      --policy-arn "$policy_arn"
  done
}

# Function to create or update a Step Functions state machine
create_or_update_state_machine() {
  local state_machine_name=$1
  local definition=$2
  local role_arn=$3
  
  echo "Creating or updating Step Functions state machine: $state_machine_name"
  
  # Check if the state machine already exists
  STATE_MACHINE_ARN=$(aws stepfunctions list-state-machines --query "stateMachines[?name=='$state_machine_name'].stateMachineArn" --output text)
  
  if [ -n "$STATE_MACHINE_ARN" ] && [ "$STATE_MACHINE_ARN" != "None" ]; then
    echo "State machine already exists, updating..."
    aws stepfunctions update-state-machine \
      --state-machine-arn "$STATE_MACHINE_ARN" \
      --definition "$definition" \
      --role-arn "$role_arn"
  else
    echo "State machine doesn't exist, creating..."
    aws stepfunctions create-state-machine \
      --name "$state_machine_name" \
      --definition "$definition" \
      --role-arn "$role_arn" \
      --type "STANDARD" \
      --tracing-configuration "enabled=true"
  fi
}

# Function to create or update an API Gateway
create_or_update_api_gateway() {
  local api_name=$1
  local role_arn=$2
  local state_machine_arn=$3
  
  echo "Creating or updating API Gateway: $api_name"
  
  # Check if the API already exists
  API_ID=$(aws apigatewayv2 get-apis --query "Items[?Name=='$api_name'].ApiId" --output text)
  
  if [ -n "$API_ID" ] && [ "$API_ID" != "None" ]; then
    echo "API already exists, updating..."
    aws apigatewayv2 update-api \
      --api-id "$API_ID" \
      --cors-configuration "AllowOrigins='*',AllowMethods='GET,POST,PUT,DELETE,OPTIONS',AllowHeaders='Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',MaxAge=300"
  else
    echo "API doesn't exist, creating..."
    API_ID=$(aws apigatewayv2 create-api \
      --name "$api_name" \
      --protocol-type "HTTP" \
      --cors-configuration "AllowOrigins='*',AllowMethods='GET,POST,PUT,DELETE,OPTIONS',AllowHeaders='Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',MaxAge=300" \
      --query "ApiId" \
      --output text)
  fi
  
  # Create or update the integration
  INTEGRATION_ID=$(aws apigatewayv2 get-integrations --api-id "$API_ID" --query "Items[?IntegrationSubtype=='StepFunctions-StartExecution'].IntegrationId" --output text)
  
  if [ -n "$INTEGRATION_ID" ] && [ "$INTEGRATION_ID" != "None" ]; then
    echo "Integration already exists, updating..."
    aws apigatewayv2 update-integration \
      --api-id "$API_ID" \
      --integration-id "$INTEGRATION_ID" \
      --integration-type "AWS_PROXY" \
      --integration-subtype "StepFunctions-StartExecution" \
      --credentials-arn "$role_arn" \
      --request-parameters "StateMachineArn='$state_machine_arn',Input='\$request.body'" \
      --payload-format-version "1.0"
  else
    echo "Integration doesn't exist, creating..."
    INTEGRATION_ID=$(aws apigatewayv2 create-integration \
      --api-id "$API_ID" \
      --integration-type "AWS_PROXY" \
      --integration-subtype "StepFunctions-StartExecution" \
      --credentials-arn "$role_arn" \
      --request-parameters "StateMachineArn='$state_machine_arn',Input='\$request.body'" \
      --payload-format-version "1.0" \
      --query "IntegrationId" \
      --output text)
  fi
  
  # Create or update the route
  ROUTE_ID=$(aws apigatewayv2 get-routes --api-id "$API_ID" --query "Items[?RouteKey=='POST /order'].RouteId" --output text)
  
  if [ -n "$ROUTE_ID" ] && [ "$ROUTE_ID" != "None" ]; then
    echo "Route already exists, updating..."
    aws apigatewayv2 update-route \
      --api-id "$API_ID" \
      --route-id "$ROUTE_ID" \
      --route-key "POST /order" \
      --target "integrations/$INTEGRATION_ID"
  else
    echo "Route doesn't exist, creating..."
    aws apigatewayv2 create-route \
      --api-id "$API_ID" \
      --route-key "POST /order" \
      --target "integrations/$INTEGRATION_ID"
  fi
  
  # Create or update the stage
  STAGE_ID=$(aws apigatewayv2 get-stages --api-id "$API_ID" --query "Items[?StageName=='\$default'].StageId" --output text)
  
  if [ -n "$STAGE_ID" ] && [ "$STAGE_ID" != "None" ]; then
    echo "Stage already exists, updating..."
    aws apigatewayv2 update-stage \
      --api-id "$API_ID" \
      --stage-name "\$default" \
      --auto-deploy "true"
  else
    echo "Stage doesn't exist, creating..."
    aws apigatewayv2 create-stage \
      --api-id "$API_ID" \
      --stage-name "\$default" \
      --auto-deploy "true"
  fi
  
  # Return the API endpoint
  API_ENDPOINT=$(aws apigatewayv2 get-api --api-id "$API_ID" --query "ApiEndpoint" --output text)
  echo "$API_ENDPOINT"
}

# Step 2: Create or update IAM roles
echo "🔧 Creating or updating IAM roles..."

# API Gateway role
API_GATEWAY_ROLE_TRUST_POLICY='{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "apigateway.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}'

create_or_update_role "apigateway-stepfunctions-role" "$API_GATEWAY_ROLE_TRUST_POLICY" ""

# Create policy for API Gateway to invoke Step Functions
API_GATEWAY_POLICY_DOCUMENT='{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["states:StartExecution"],
    "Resource": ["arn:aws:states:'"$REGION"':'"$ACCOUNT_ID"':stateMachine:OrderSagaStateMachine"]
  }]
}'

# Check if the policy already exists
if aws iam get-policy --policy-arn "arn:aws:iam::$ACCOUNT_ID:policy/apigateway-start-execution" >/dev/null 2>&1; then
  echo "API Gateway policy already exists, updating..."
  aws iam create-policy-version \
    --policy-arn "arn:aws:iam::$ACCOUNT_ID:policy/apigateway-start-execution" \
    --policy-document "$API_GATEWAY_POLICY_DOCUMENT" \
    --set-as-default
else
  echo "API Gateway policy doesn't exist, creating..."
  aws iam create-policy \
    --policy-name "apigateway-start-execution" \
    --policy-document "$API_GATEWAY_POLICY_DOCUMENT"
fi

# Attach the policy to the role
aws iam attach-role-policy \
  --role-name "apigateway-stepfunctions-role" \
  --policy-arn "arn:aws:iam::$ACCOUNT_ID:policy/apigateway-start-execution"

# Step Functions role
STEP_FUNCTIONS_ROLE_TRUST_POLICY='{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "states.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}'

create_or_update_role "order-saga-sfn-role" "$STEP_FUNCTIONS_ROLE_TRUST_POLICY" "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"

# Lambda execution role
LAMBDA_EXEC_ROLE_TRUST_POLICY='{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "lambda.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}'

create_or_update_role "lambda_exec_role" "$LAMBDA_EXEC_ROLE_TRUST_POLICY" "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"

# Get the role ARNs
API_GATEWAY_ROLE_ARN=$(aws iam get-role --role-name "apigateway-stepfunctions-role" --query "Role.Arn" --output text)
STEP_FUNCTIONS_ROLE_ARN=$(aws iam get-role --role-name "order-saga-sfn-role" --query "Role.Arn" --output text)
LAMBDA_EXEC_ROLE_ARN=$(aws iam get-role --role-name "lambda_exec_role" --query "Role.Arn" --output text)

# Step 3: Create or update Lambda functions
echo "🔧 Creating or updating Lambda functions..."

# Create Lambda function packages
echo "Creating Lambda function packages..."
mkdir -p lambda-packages

# Order service Lambda function
cat > lambda-packages/order_service.py << EOF
import json
import os
import urllib.request
import urllib.parse
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    logger.info(f"Event: {json.dumps(event)}")
    
    # Get the API endpoint from environment variables
    api_endpoint = os.environ.get('API_ENDPOINT_ORDERS')
    
    if not api_endpoint:
        logger.error("API_ENDPOINT_ORDERS environment variable not set")
        return {
            'statusCode': 500,
            'body': json.dumps('API endpoint not configured')
        }
    
    try:
        # Extract order data from the event
        input_data = event.get('input', {})
        
        # Prepare the request data
        data = json.dumps(input_data).encode('utf-8')
        
        # Create the request
        req = urllib.request.Request(
            api_endpoint,
            data=data,
            headers={'Content-Type': 'application/json'}
        )
        
        # Send the request to the order service
        logger.info(f"Sending request to {api_endpoint}")
        with urllib.request.urlopen(req) as response:
            response_body = response.read()
            logger.info(f"Response: {response_body}")
            
            # Parse the response
            response_data = json.loads(response_body)
            
            # Return the response
            return {
                'statusCode': response.getcode(),
                'body': response_data,
                'orderId': input_data.get('orderId')
            }
    
    except urllib.error.HTTPError as e:
        logger.error(f"HTTPError: {e.code} - {e.reason}")
        return {
            'statusCode': e.code,
            'body': e.reason,
            'orderId': input_data.get('orderId')
        }
    
    except Exception as e:
        logger.error(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': str(e),
            'orderId': input_data.get('orderId')
        }
EOF

cd lambda-packages
zip -r order_service_function.zip order_service.py
cd ..

# Deploy the Lambda functions
ORDER_SERVICE_ENV='{"Variables":{"API_ENDPOINT_ORDERS":"http://k8s-orders-orders-39b18f3a4b-1266732517.us-east-1.elb.amazonaws.com/api/orders"}}'
INVENTORY_SERVICE_ENV='{"Variables":{"API_ENDPOINT_INVENTORY":"http://k8s-inventory-inventory-39b18f3a4b-1266732517.us-east-1.elb.amazonaws.com/api/inventory"}}'
PAYMENT_SERVICE_ENV='{"Variables":{"API_ENDPOINT_PAYMENT":"http://k8s-payments-payments-39b18f3a4b-1266732517.us-east-1.elb.amazonaws.com/api/payments"}}'
RELEASE_INVENTORY_ENV='{"Variables":{"API_ENDPOINT_RELEASE_INVENTORY":"http://k8s-inventory-inventory-39b18f3a4b-1266732517.us-east-1.elb.amazonaws.com/api/inventory/release"}}'
CANCEL_ORDER_ENV='{"Variables":{"API_ENDPOINT_CANCEL_ORDER":"http://k8s-orders-orders-39b18f3a4b-1266732517.us-east-1.elb.amazonaws.com/api/orders/cancel"}}'

deploy_lambda_function "orderServiceFunction" "order_service.lambda_handler" "lambda-packages/order_service_function.zip" "$LAMBDA_EXEC_ROLE_ARN" "$ORDER_SERVICE_ENV"

# Get the Lambda function ARNs
ORDER_SERVICE_ARN=$(aws lambda get-function --function-name "orderServiceFunction" --query "Configuration.FunctionArn" --output text)
INVENTORY_SERVICE_ARN=$(aws lambda get-function --function-name "inventoryServiceFunction" --query "Configuration.FunctionArn" --output text 2>/dev/null || echo "")
PAYMENT_SERVICE_ARN=$(aws lambda get-function --function-name "paymentServiceFunction" --query "Configuration.FunctionArn" --output text 2>/dev/null || echo "")
RELEASE_INVENTORY_ARN=$(aws lambda get-function --function-name "releaseInventoryFunction" --query "Configuration.FunctionArn" --output text 2>/dev/null || echo "")
CANCEL_ORDER_ARN=$(aws lambda get-function --function-name "cancelOrderFunction" --query "Configuration.FunctionArn" --output text 2>/dev/null || echo "")

# Step 4: Create or update Step Functions state machine
echo "🔧 Creating or updating Step Functions state machine..."

# Create the Step Functions state machine definition
STATE_MACHINE_DEFINITION='{
  "Comment": "State machine for processing the order saga with Choice states",
  "StartAt": "OrderService",
  "States": {
    "OrderService": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "FunctionName": "'"$ORDER_SERVICE_ARN"'",
        "Payload": { "input.$": "$" }
      },
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "Next": "FailSaga"
        }
      ],
      "Next": "InventoryService"
    },
    "InventoryService": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "FunctionName": "'"$INVENTORY_SERVICE_ARN"'",
        "Payload": { "input.$": "$" }
      },
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "Next": "FailSaga"
        }
      ],
      "Next": "CheckInventory"
    },
    "CheckInventory": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.Payload.statusCode",
          "NumericEquals": 404,
          "Next": "CancelOrder"
        }
      ],
      "Default": "PaymentService"
    },
    "PaymentService": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "FunctionName": "'"$PAYMENT_SERVICE_ARN"'",
        "Payload": { "input.$": "$" }
      },
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "Next": "FailSaga"
        }
      ],
      "Next": "CheckPayment"
    },
    "CheckPayment": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.Payload.statusCode",
          "NumericEquals": 402,
          "Next": "ReleaseInventory"
        }
      ],
      "Default": "CompleteSaga"
    },
    "ReleaseInventory": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "FunctionName": "'"$RELEASE_INVENTORY_ARN"'",
        "Payload": { "input.$": "$" }
      },
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "Next": "FailSaga"
        }
      ],
      "Next": "CancelOrder"
    },
    "CancelOrder": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "FunctionName": "'"$CANCEL_ORDER_ARN"'",
        "Payload": { "input.$": "$" }
      },
      "Next": "FailSaga"
    },
    "CompleteSaga": {
      "Type": "Succeed"
    },
    "FailSaga": {
      "Type": "Fail",
      "Cause": "SagaFailed"
    }
  }
}'

create_or_update_state_machine "OrderSagaStateMachine" "$STATE_MACHINE_DEFINITION" "$STEP_FUNCTIONS_ROLE_ARN"

# Get the Step Functions state machine ARN
STATE_MACHINE_ARN=$(aws stepfunctions list-state-machines --query "stateMachines[?name=='OrderSagaStateMachine'].stateMachineArn" --output text)

# Step 5: Create or update API Gateway
echo "🔧 Creating or updating API Gateway..."

API_ENDPOINT=$(create_or_update_api_gateway "orders-saga-api" "$API_GATEWAY_ROLE_ARN" "$STATE_MACHINE_ARN")

echo "✅ Step Functions and API Gateway deployed successfully."
echo "API Gateway endpoint: ${API_ENDPOINT}"
echo ""
echo "To test the API, you can use the following curl command:"
echo "curl -X POST ${API_ENDPOINT}/order -H 'Content-Type: application/json' -d '{\"orderId\": \"123\", \"customerId\": \"456\", \"items\": [{\"productId\": \"789\", \"quantity\": 1}]}'"