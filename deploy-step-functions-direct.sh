#!/bin/bash

# Script to deploy Step Functions and API Gateway using AWS CLI directly
# This approach bypasses Terraform completely for resources that already exist

set -e

REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
DEBUG=${DEBUG:-"false"}

# Function to log debug information if DEBUG is enabled
debug_log() {
  if [ "$DEBUG" == "true" ]; then
    echo "DEBUG: $1"
  fi
}

# Function to log errors
error_log() {
  echo "ERROR: $1" >&2
}

echo "🚀 Deploying Step Functions and API Gateway using AWS CLI..."

# Step 1: Package Lambda functions
echo "📦 Packaging Lambda functions..."
./package-lambda-functions.sh || {
  error_log "Failed to package Lambda functions, but continuing..."
}

# Create directory for Lambda function packages if it doesn't exist
mkdir -p lambda-packages# Fu
nction to safely execute AWS CLI commands
aws_command() {
  debug_log "Running AWS command: aws $*"
  aws "$@"
  return $?
}

# Function to create or update a Lambda function
deploy_lambda_function() {
  local function_name=$1
  local handler=$2
  local zip_file=$3
  local role_arn=$4
  local environment=$5
  
  echo "Deploying Lambda function: $function_name"
  
  # Check if the function already exists
  if aws_command lambda get-function --function-name "$function_name" >/dev/null 2>&1; then
    echo "Function already exists, updating..."
    aws_command lambda update-function-code \
      --function-name "$function_name" \
      --zip-file "fileb://$zip_file" \
      --region "$REGION" || {
        error_log "Failed to update Lambda function code: $function_name"
        return 1
      }
    
    aws_command lambda update-function-configuration \
      --function-name "$function_name" \
      --handler "$handler" \
      --runtime "python3.9" \
      --timeout 30 \
      --memory-size 256 \
      --environment "$environment" \
      --region "$REGION" || {
        error_log "Failed to update Lambda function configuration: $function_name"
        return 1
      }
  else
    echo "Function doesn't exist, creating..."
    aws_command lambda create-function \
      --function-name "$function_name" \
      --handler "$handler" \
      --runtime "python3.9" \
      --role "$role_arn" \
      --timeout 30 \
      --memory-size 256 \
      --environment "$environment" \
      --zip-file "fileb://$zip_file" \
      --region "$REGION" || {
        error_log "Failed to create Lambda function: $function_name"
        return 1
      }
  fi
  
  return 0
}

# Function to create or update an IAM role
create_or_update_role() {
  local role_name=$1
  local trust_policy=$2
  local policy_arns=$3
  
  echo "Creating or updating IAM role: $role_name"
  
  # Check if the role already exists
  if aws_command iam get-role --role-name "$role_name" >/dev/null 2>&1; then
    echo "Role already exists, updating trust policy..."
    aws_command iam update-assume-role-policy \
      --role-name "$role_name" \
      --policy-document "$trust_policy" || {
        error_log "Failed to update trust policy for role: $role_name"
        return 1
      }
  else
    echo "Role doesn't exist, creating..."
    aws_command iam create-role \
      --role-name "$role_name" \
      --assume-role-policy "$trust_policy" || {
        error_log "Failed to create role: $role_name"
        return 1
      }
  fi
  
  # Attach policies
  for policy_arn in $policy_arns; do
    echo "Attaching policy: $policy_arn"
    aws_command iam attach-role-policy \
      --role-name "$role_name" \
      --policy-arn "$policy_arn" || {
        error_log "Failed to attach policy: $policy_arn to role: $role_name"
      }
  done
  
  return 0
}# Fun
ction to create or update a Step Functions state machine
create_or_update_state_machine() {
  local state_machine_name=$1
  local definition=$2
  local role_arn=$3
  
  echo "Creating or updating Step Functions state machine: $state_machine_name"
  
  # Check if the state machine already exists
  STATE_MACHINE_ARN=$(aws_command stepfunctions list-state-machines --query "stateMachines[?name=='$state_machine_name'].stateMachineArn" --output text)
  
  if [ -n "$STATE_MACHINE_ARN" ] && [ "$STATE_MACHINE_ARN" != "None" ]; then
    echo "State machine already exists, updating..."
    aws_command stepfunctions update-state-machine \
      --state-machine-arn "$STATE_MACHINE_ARN" \
      --definition "$definition" \
      --role-arn "$role_arn" || {
        error_log "Failed to update state machine: $state_machine_name"
        return 1
      }
  else
    echo "State machine doesn't exist, creating..."
    aws_command stepfunctions create-state-machine \
      --name "$state_machine_name" \
      --definition "$definition" \
      --role-arn "$role_arn" \
      --type "STANDARD" \
      --tracing-configuration "enabled=true" || {
        error_log "Failed to create state machine: $state_machine_name"
        return 1
      }
  fi
  
  return 0
}

# Function to create or update an API Gateway
create_or_update_api_gateway() {
  local api_name=$1
  local role_arn=$2
  local state_machine_arn=$3
  
  echo "Creating or updating API Gateway: $api_name"
  
  # Check if the API already exists
  API_ID=$(aws_command apigatewayv2 get-apis --query "Items[?Name=='$api_name'].ApiId" --output text)
  
  if [ -n "$API_ID" ] && [ "$API_ID" != "None" ]; then
    echo "API already exists, updating..."
    aws_command apigatewayv2 update-api \
      --api-id "$API_ID" \
      --cors-configuration "AllowOrigins='*',AllowMethods='GET,POST,PUT,DELETE,OPTIONS',AllowHeaders='Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',MaxAge=300" || {
        error_log "Failed to update API Gateway: $api_name"
        return 1
      }
  else
    echo "API doesn't exist, creating..."
    API_ID=$(aws_command apigatewayv2 create-api \
      --name "$api_name" \
      --protocol-type "HTTP" \
      --cors-configuration "AllowOrigins='*',AllowMethods='GET,POST,PUT,DELETE,OPTIONS',AllowHeaders='Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',MaxAge=300" \
      --query "ApiId" \
      --output text) || {
        error_log "Failed to create API Gateway: $api_name"
        return 1
      }
  fi  
  # Cre
ate or update the integration
  INTEGRATION_ID=$(aws_command apigatewayv2 get-integrations --api-id "$API_ID" --query "Items[?IntegrationSubtype=='StepFunctions-StartExecution'].IntegrationId" --output text)
  
  if [ -n "$INTEGRATION_ID" ] && [ "$INTEGRATION_ID" != "None" ]; then
    echo "Integration already exists, updating..."
    aws_command apigatewayv2 update-integration \
      --api-id "$API_ID" \
      --integration-id "$INTEGRATION_ID" \
      --integration-type "AWS_PROXY" \
      --integration-subtype "StepFunctions-StartExecution" \
      --credentials-arn "$role_arn" \
      --request-parameters "StateMachineArn='$state_machine_arn',Input='\$request.body'" \
      --payload-format-version "1.0" || {
        error_log "Failed to update API Gateway integration"
        return 1
      }
  else
    echo "Integration doesn't exist, creating..."
    INTEGRATION_ID=$(aws_command apigatewayv2 create-integration \
      --api-id "$API_ID" \
      --integration-type "AWS_PROXY" \
      --integration-subtype "StepFunctions-StartExecution" \
      --credentials-arn "$role_arn" \
      --request-parameters "StateMachineArn='$state_machine_arn',Input='\$request.body'" \
      --payload-format-version "1.0" \
      --query "IntegrationId" \
      --output text) || {
        error_log "Failed to create API Gateway integration"
        return 1
      }
  fi
  
  # Create or update the route
  ROUTE_ID=$(aws_command apigatewayv2 get-routes --api-id "$API_ID" --query "Items[?RouteKey=='POST /order'].RouteId" --output text)
  
  if [ -n "$ROUTE_ID" ] && [ "$ROUTE_ID" != "None" ]; then
    echo "Route already exists, updating..."
    aws_command apigatewayv2 update-route \
      --api-id "$API_ID" \
      --route-id "$ROUTE_ID" \
      --route-key "POST /order" \
      --target "integrations/$INTEGRATION_ID" || {
        error_log "Failed to update API Gateway route"
        return 1
      }
  else
    echo "Route doesn't exist, creating..."
    aws_command apigatewayv2 create-route \
      --api-id "$API_ID" \
      --route-key "POST /order" \
      --target "integrations/$INTEGRATION_ID" || {
        error_log "Failed to create API Gateway route"
        return 1
      }
  fi  
 
 # Create or update the stage
  STAGE_ID=$(aws_command apigatewayv2 get-stages --api-id "$API_ID" --query "Items[?StageName=='\$default'].StageId" --output text)
  
  if [ -n "$STAGE_ID" ] && [ "$STAGE_ID" != "None" ]; then
    echo "Stage already exists, updating..."
    aws_command apigatewayv2 update-stage \
      --api-id "$API_ID" \
      --stage-name "\$default" \
      --auto-deploy "true" || {
        error_log "Failed to update API Gateway stage"
        return 1
      }
  else
    echo "Stage doesn't exist, creating..."
    aws_command apigatewayv2 create-stage \
      --api-id "$API_ID" \
      --stage-name "\$default" \
      --auto-deploy "true" || {
        error_log "Failed to create API Gateway stage"
        return 1
      }
  fi
  
  # Return the API endpoint
  API_ENDPOINT=$(aws_command apigatewayv2 get-api --api-id "$API_ID" --query "ApiEndpoint" --output text)
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
}'# Check 
if the policy already exists
if aws_command iam get-policy --policy-arn "arn:aws:iam::$ACCOUNT_ID:policy/apigateway-start-execution" >/dev/null 2>&1; then
  echo "API Gateway policy already exists, updating..."
  aws_command iam create-policy-version \
    --policy-arn "arn:aws:iam::$ACCOUNT_ID:policy/apigateway-start-execution" \
    --policy-document "$API_GATEWAY_POLICY_DOCUMENT" \
    --set-as-default || {
      error_log "Failed to update API Gateway policy"
    }
else
  echo "API Gateway policy doesn't exist, creating..."
  aws_command iam create-policy \
    --policy-name "apigateway-start-execution" \
    --policy-document "$API_GATEWAY_POLICY_DOCUMENT" || {
      error_log "Failed to create API Gateway policy"
    }
fi

# Attach the policy to the role
aws_command iam attach-role-policy \
  --role-name "apigateway-stepfunctions-role" \
  --policy-arn "arn:aws:iam::$ACCOUNT_ID:policy/apigateway-start-execution" || {
    error_log "Failed to attach policy to API Gateway role"
  }

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

# Create policy for Step Functions to invoke Lambda
STEP_FUNCTIONS_POLICY_DOCUMENT='{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["lambda:InvokeFunction"],
    "Resource": ["arn:aws:lambda:'"$REGION"':'"$ACCOUNT_ID"':function:*"]
  }]
}'# Check if 
the policy already exists
if aws_command iam get-policy --policy-arn "arn:aws:iam::$ACCOUNT_ID:policy/step-functions-invoke-lambda" >/dev/null 2>&1; then
  echo "Step Functions policy already exists, updating..."
  aws_command iam create-policy-version \
    --policy-arn "arn:aws:iam::$ACCOUNT_ID:policy/step-functions-invoke-lambda" \
    --policy-document "$STEP_FUNCTIONS_POLICY_DOCUMENT" \
    --set-as-default || {
      error_log "Failed to update Step Functions policy"
    }
else
  echo "Step Functions policy doesn't exist, creating..."
  aws_command iam create-policy \
    --policy-name "step-functions-invoke-lambda" \
    --policy-document "$STEP_FUNCTIONS_POLICY_DOCUMENT" || {
      error_log "Failed to create Step Functions policy"
    }
fi

# Attach the policy to the role
aws_command iam attach-role-policy \
  --role-name "order-saga-sfn-role" \
  --policy-arn "arn:aws:iam::$ACCOUNT_ID:policy/step-functions-invoke-lambda" || {
    error_log "Failed to attach policy to Step Functions role"
  }

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
API_GATEWAY_ROLE_ARN=$(aws_command iam get-role --role-name "apigateway-stepfunctions-role" --query "Role.Arn" --output text)
STEP_FUNCTIONS_ROLE_ARN=$(aws_command iam get-role --role-name "order-saga-sfn-role" --query "Role.Arn" --output text)
LAMBDA_EXEC_ROLE_ARN=$(aws_command iam get-role --role-name "lambda_exec_role" --query "Role.Arn" --output text)# Step 3:
 Create or update Lambda functions
echo "🔧 Creating or update Lambda functions..."

# Create Lambda function packages
echo "Creating Lambda function packages..."
mkdir -p lambda-packages

# Check if Lambda packages exist, if not create them
if [ ! -f "lambda-packages/order_service_function.zip" ]; then
  echo "Creating order service Lambda function package..."
  
  # Create a temporary directory
  TEMP_DIR=$(mktemp -d)
  
  # Create the Python file
  cat > "$TEMP_DIR/order_service.py" << EOF
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