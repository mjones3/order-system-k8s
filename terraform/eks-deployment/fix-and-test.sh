#!/bin/bash

echo "🔧 Fixing Terraform configuration issues..."

# Clean up any duplicate files
echo "1. Cleaning up duplicate files..."
rm -f *-simple.tf
rm -f *-complex.tf

# Clean terraform state
echo "2. Cleaning terraform state..."
rm -rf .terraform/
rm -f .terraform.lock.hcl
rm -f *.tfplan
rm -f *.log

# Check current files
echo "3. Current configuration files:"
ls -la *.tf

# Test basic validation
echo ""
echo "4. Testing configuration..."
terraform init

if [ $? -eq 0 ]; then
    echo "✅ Terraform init successful"
    
    echo "5. Testing validation..."
    terraform validate
    
    if [ $? -eq 0 ]; then
        echo "✅ Configuration is valid"
        
        echo "6. Testing plan (this may take a moment)..."
        terraform plan -var-file=terraform.tfvars -out=test.tfplan
        
        if [ $? -eq 0 ]; then
            echo "✅ Plan successful! Configuration is working"
            rm -f test.tfplan
        else
            echo "❌ Plan failed - check the error above"
        fi
    else
        echo "❌ Configuration validation failed"
    fi
else
    echo "❌ Terraform init failed - check the error above"
fi

echo ""
echo "💡 If successful, you can now run: terraform apply -var-file=terraform.tfvars"