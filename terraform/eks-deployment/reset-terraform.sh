#!/bin/bash

echo "🧹 Completely resetting Terraform state..."

# Remove lock file if it exists
if [ -f ".terraform.tfstate.lock.info" ]; then
    echo "🔒 Removing terraform lock file..."
    rm -f .terraform.tfstate.lock.info
    echo "✅ Lock file removed"
else
    echo "✅ No lock file found"
fi

# Remove all state files
echo "🗑️  Removing all Terraform state files..."
rm -f terraform.tfstate*
rm -f .terraform.tfstate*
rm -f *.tfplan
echo "✅ State files removed"

# Remove terraform directory (will need to re-init)
echo "📦 Removing .terraform directory..."
rm -rf .terraform/
echo "✅ .terraform directory removed"

# Remove any log files
echo "📋 Removing log files..."
rm -f *.log
echo "✅ Log files removed"

echo ""
echo "🎉 Terraform completely reset!"
echo ""
echo "⚠️  WARNING: This does NOT delete AWS resources!"
echo "   Any AWS resources that were created are still running and will incur costs."
echo ""
echo "🔄 Next steps:"
echo "1. Run: terraform init"
echo "2. Check AWS console for any resources to manually delete"
echo "3. Start fresh deployment if needed"
echo ""
echo "💡 To check for AWS resources that might still exist:"
echo "   ./check-aws-resources.sh"