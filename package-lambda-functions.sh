#!/bin/bash

# Script to package Lambda functions
set -e

echo "📦 Packaging Lambda functions..."

# Create the functions directory if it doesn't exist
mkdir -p apps/functions

# Function to package a Lambda function
package_function() {
  local function_name=$1
  local function_dir="apps/functions/${function_name}-handler"
  
  echo "📦 Packaging ${function_name}..."
  
  # Create the function directory if it doesn't exist
  mkdir -p ${function_dir}
  
  # Create a ZIP file for the function
  cd ${function_dir}
  zip -r ${function_name}Function.zip lambda_function.py
  cd - > /dev/null
  
  echo "✅ ${function_name} packaged successfully."
}

# Package all Lambda functions
package_function "order-service"
package_function "inventory-service"
package_function "payment-service"
package_function "cancel-order"
package_function "release-inventory"

echo "✅ All Lambda functions packaged successfully."