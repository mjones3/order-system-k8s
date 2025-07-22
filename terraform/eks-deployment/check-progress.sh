#!/bin/bash

echo "🔍 Checking EKS deployment progress..."

# Check if EKS cluster exists and its status
echo "📊 EKS Cluster Status:"
aws eks describe-cluster --name order-system-cluster --region us-east-1 --query 'cluster.status' --output text 2>/dev/null || echo "Cluster not found or still creating..."

# Check CloudFormation stacks (EKS uses CloudFormation)
echo ""
echo "☁️  CloudFormation Stacks:"
aws cloudformation list-stacks --stack-status-filter CREATE_IN_PROGRESS UPDATE_IN_PROGRESS --query 'StackSummaries[?contains(StackName, `eks`) || contains(StackName, `order`)].{Name:StackName,Status:StackStatus}' --output table

# Check RDS instances
echo ""
echo "🗄️  RDS Instances:"
aws rds describe-db-instances --query 'DBInstances[?contains(DBInstanceIdentifier, `order`) || contains(DBInstanceIdentifier, `inventory`) || contains(DBInstanceIdentifier, `payment`)].{Name:DBInstanceIdentifier,Status:DBInstanceStatus}' --output table 2>/dev/null || echo "No RDS instances found yet..."

# Check VPC creation
echo ""
echo "🌐 VPC Status:"
aws ec2 describe-vpcs --filters "Name=tag:project,Values=order-system" --query 'Vpcs[].{VpcId:VpcId,State:State,CidrBlock:CidrBlock}' --output table 2>/dev/null || echo "No VPCs found yet..."

echo ""
echo "💡 If resources are showing 'CREATE_IN_PROGRESS', your deployment is working!"
echo "💡 EKS cluster creation typically takes 10-15 minutes"
echo "💡 RDS creation typically takes 5-10 minutes"