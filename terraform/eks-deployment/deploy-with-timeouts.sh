#!/bin/bash

# EKS Deployment with Extended Timeouts and Verbose Logging
set -e

echo "🚀 Starting EKS deployment with extended timeouts and verbose logging..."

# Set extended timeouts and verbose logging
export TF_PLUGIN_TIMEOUT=600  # 10 minutes for plugin timeout
export AWS_MAX_ATTEMPTS=10
export AWS_RETRY_MODE=adaptive
export TF_LOG=DEBUG
export TF_LOG_PATH=./terraform-verbose.log

# Check if required files exist
if [ ! -f "terraform.tfvars" ]; then
    echo "❌ terraform.tfvars file not found!"
    exit 1
fi

echo "⏱️  Using extended timeouts and verbose logging:"
echo "   - Plugin timeout: 10 minutes"
echo "   - AWS retry attempts: 10"
echo "   - AWS retry mode: adaptive"
echo "   - Log level: DEBUG"
echo "   - Log file: terraform-verbose.log"
echo ""
echo "💡 Monitor progress in another terminal with:"
echo "   tail -f terraform-verbose.log"
echo ""

# Clean start
echo "🧹 Cleaning previous state..."
rm -rf .terraform/
rm -f .terraform.lock.hcl
rm -f terraform-verbose.log

# Initialize with verbose output (no timeout on macOS)
echo "📦 Initializing Terraform (may take a few minutes)..."
echo "📋 Detailed logs are being written to terraform-verbose.log"
terraform init -no-color 2>&1 | tee -a init.log || {
    echo "❌ Terraform init failed"
    echo "📋 Check init.log for details"
    exit 1
}

echo "✅ Terraform initialized successfully!"

# Plan with timeout and verbose output
echo "📋 Planning deployment with verbose output..."
echo "⏳ This may take several minutes, progress logged to terraform-verbose.log"

# Start background monitoring
(
    sleep 10  # Give terraform time to start
    while [ ! -f "eks.tfplan" ] && pgrep -f "terraform plan" > /dev/null 2>&1; do
        echo "⏳ Planning in progress... ($(date '+%H:%M:%S'))"
        if [ -f "terraform-verbose.log" ]; then
            # Show recent activity
            tail -5 terraform-verbose.log | grep -E "(Creating|Reading|Refreshing)" | tail -1 || true
        fi
        sleep 30
    done
) &
MONITOR_PID=$!

terraform plan -var-file="terraform.tfvars" -out=eks.tfplan -no-color || {
    kill $MONITOR_PID 2>/dev/null || true
    echo "❌ Terraform plan failed"
    echo "📋 Check terraform-verbose.log for details"
    exit 1
}

kill $MONITOR_PID 2>/dev/null || true
echo "✅ Planning completed successfully!"

echo "🔍 Review the plan above. Do you want to continue? (y/N)"
read -r response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "❌ Deployment cancelled"
    exit 1
fi

# Apply with extended timeout and progress monitoring
echo "🏗️  Applying infrastructure (this will take 15-20 minutes)..."
echo "📊 Progress will be logged to terraform-verbose.log"
echo "💡 You can monitor in another terminal with: tail -f terraform-verbose.log"
echo ""

# Start background progress monitoring
(
    sleep 30  # Give terraform time to start
    while pgrep -f "terraform apply" > /dev/null 2>&1; do
        current_time=$(date '+%H:%M:%S')
        echo "⏳ Deployment in progress... ($current_time)"
        
        if [ -f "terraform-verbose.log" ]; then
            # Show what's currently being created
            recent_activity=$(tail -20 terraform-verbose.log | grep -E "(Creating|Modifying|Still creating)" | tail -1 || echo "")
            if [ -n "$recent_activity" ]; then
                echo "   Current: $(echo $recent_activity | sed 's/.*\(aws_[^:]*\).*/\1/')"
            fi
            
            # Check for EKS cluster creation
            if grep -q "aws_eks_cluster" terraform-verbose.log 2>/dev/null; then
                echo "   🎯 EKS cluster creation detected"
            fi
            
            # Check for RDS creation
            if grep -q "aws_db_instance" terraform-verbose.log 2>/dev/null; then
                echo "   🗄️  RDS database creation detected"
            fi
        fi
        sleep 60  # Check every minute
    done
) &
PROGRESS_PID=$!

terraform apply eks.tfplan -no-color || {
    kill $PROGRESS_PID 2>/dev/null || true
    echo "❌ Terraform apply failed"
    echo "📋 Check terraform-verbose.log for details"
    echo "💡 Check AWS console for partially created resources"
    exit 1
}

kill $PROGRESS_PID 2>/dev/null || true

echo ""
echo "🎉 Infrastructure deployment completed!"
echo ""

# Wait for EKS cluster to be ready
if terraform output cluster_endpoint >/dev/null 2>&1; then
    echo "⏳ Waiting for EKS cluster to be fully ready..."
    aws eks wait cluster-active --name order-system-cluster --region us-east-1 || {
        echo "❌ EKS cluster failed to become active"
        exit 1
    }
    
    # Update kubeconfig
    echo "🔧 Updating kubeconfig..."
    aws eks update-kubeconfig --name order-system-cluster --region us-east-1
    
    echo "✅ EKS cluster is ready!"
fi

echo ""
echo "📊 Deployment Summary:"
echo "📋 Verbose logs saved to: terraform-verbose.log"
echo "📋 Init logs saved to: init.log"

if terraform output cluster_endpoint >/dev/null 2>&1; then
    echo "🔗 Cluster endpoint: $(terraform output -raw cluster_endpoint)"
fi

echo ""
echo "🎉 Deployment completed successfully!"