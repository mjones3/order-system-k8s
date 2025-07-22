#!/bin/bash

echo "🔧 Fixing AWS provider timeout issues..."

# 1. Increase system limits
echo "1. Setting environment variables for better performance..."
export TF_PLUGIN_TIMEOUT=600  # 10 minutes instead of 60 seconds
export AWS_MAX_ATTEMPTS=3     # Reduce AWS API calls
export AWS_RETRY_MODE=standard # Use standard retry mode
export TF_LOG=WARN            # Reduce logging overhead

# 2. Clear any cached provider data
echo "2. Clearing provider cache..."
rm -rf ~/.terraform.d/plugin-cache/ 2>/dev/null || true
rm -rf .terraform/providers/

# 3. Clean restart
echo "3. Clean terraform restart..."
rm -rf .terraform/
rm -f .terraform.lock.hcl

# 4. Initialize with reduced concurrency
echo "4. Initializing with reduced concurrency..."
terraform init -parallelism=1

if [ $? -eq 0 ]; then
    echo "✅ Init successful with timeout fix"
    
    echo "5. Testing validation..."
    terraform validate
    
    if [ $? -eq 0 ]; then
        echo "✅ Validation successful!"
        echo "💡 You can now try: terraform plan -var-file=terraform.tfvars"
    else
        echo "❌ Validation still failing"
    fi
else
    echo "❌ Init still failing - this may be a system-level issue"
    echo "💡 Try restarting your machine or closing other applications"
fi