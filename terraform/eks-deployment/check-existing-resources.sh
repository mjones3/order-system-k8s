#!/bin/bash

# Script to check existing AWS resources
set -e

echo "🔍 Checking existing AWS resources..."

# Check VPCs
echo "📊 Existing VPCs with project=order-system tag:"
aws ec2 describe-vpcs --filters "Name=tag:project,Values=order-system" \
    --query "Vpcs[*].{VpcId:VpcId,CidrBlock:CidrBlock,Tags:Tags[?Key=='Name'].Value|[0]}" \
    --output table

# Check Subnets
echo -e "\n📊 Existing Subnets in VPC vpc-024c0c2f1ea047c09:"
aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-024c0c2f1ea047c09" \
    --query "Subnets[*].{SubnetId:SubnetId,CidrBlock:CidrBlock,AZ:AvailabilityZone,Name:Tags[?Key=='Name'].Value|[0],Type:Tags[?Key=='Type'].Value|[0]}" \
    --output table

# Check DB Subnet Groups
echo -e "\n📊 Existing DB Subnet Groups:"
aws rds describe-db-subnet-groups \
    --query "DBSubnetGroups[*].{Name:DBSubnetGroupName,VpcId:VpcId,Subnets:Subnets[*].SubnetIdentifier}" \
    --output table

# Check RDS Instances
echo -e "\n📊 Existing RDS Instances:"
aws rds describe-db-instances \
    --query "DBInstances[*].{DBInstanceId:DBInstanceIdentifier,Engine:Engine,Status:DBInstanceStatus,SubnetGroup:DBSubnetGroup.DBSubnetGroupName,VpcId:DBSubnetGroup.VpcId}" \
    --output table

# Check EKS Clusters
echo -e "\n📊 Existing EKS Clusters:"
aws eks list-clusters --output table

# Check Security Groups
echo -e "\n📊 Existing Security Groups in VPC vpc-024c0c2f1ea047c09:"
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=vpc-024c0c2f1ea047c09" \
    --query "SecurityGroups[*].{GroupId:GroupId,GroupName:GroupName,Description:Description}" \
    --output table

echo -e "\n✅ Resource check completed!"