#!/bin/bash

echo "🛑 Killing stuck Terraform processes..."

# Kill all terraform processes
echo "Killing terraform processes..."
pkill -f terraform || echo "No terraform processes to kill"

# Kill terraform provider processes
echo "Killing terraform provider processes..."
pkill -f terraform-provider || echo "No provider processes to kill"

# Remove lock files
echo "Removing lock files..."
rm -f .terraform.tfstate.lock.info

# Check if processes are gone
sleep 2
REMAINING=$(ps aux | grep terraform | grep -v grep | wc -l)
if [ $REMAINING -gt 0 ]; then
    echo "⚠️  Some processes still running, force killing..."
    pkill -9 -f terraform
    pkill -9 -f terraform-provider
fi

echo "✅ All terraform processes killed"
echo ""
echo "🔄 Ready to restart deployment"