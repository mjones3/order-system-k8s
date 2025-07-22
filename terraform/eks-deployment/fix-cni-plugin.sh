#!/bin/bash

# Script to fix CNI plugin initialization issues
set -e

CLUSTER_NAME="order-system-cluster"
REGION="us-east-1"

echo "🔧 Fixing CNI plugin initialization issues..."

# Update kubeconfig
echo "📝 Updating kubeconfig..."
aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${REGION}

# Get the node role name
echo "🔍 Getting node role name..."
NODEGROUP_NAME=$(aws eks list-nodegroups --cluster-name ${CLUSTER_NAME} --query 'nodegroups[-1]' --output text)
NODE_ROLE_ARN=$(aws eks describe-nodegroup --cluster-name ${CLUSTER_NAME} --nodegroup-name ${NODEGROUP_NAME} --query 'nodegroup.nodeRole' --output text)
NODE_ROLE=$(echo ${NODE_ROLE_ARN} | awk -F/ '{print $2}')
echo "Node role: ${NODE_ROLE}"

# Attach required policies
echo "📎 Attaching required policies to node role..."
aws iam attach-role-policy --role-name ${NODE_ROLE} --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
aws iam attach-role-policy --role-name ${NODE_ROLE} --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
aws iam attach-role-policy --role-name ${NODE_ROLE} --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly

# Create IRSA for VPC CNI
echo "🔑 Creating IRSA for VPC CNI..."
eksctl utils associate-iam-oidc-provider --cluster=${CLUSTER_NAME} --approve

# Create IAM policy for VPC CNI
echo "📜 Creating IAM policy for VPC CNI..."
cat <<EOF > vpc-cni-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:AssignPrivateIpAddresses",
        "ec2:AttachNetworkInterface",
        "ec2:CreateNetworkInterface",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeInstances",
        "ec2:DescribeTags",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DescribeInstanceTypes",
        "ec2:DetachNetworkInterface",
        "ec2:ModifyNetworkInterfaceAttribute",
        "ec2:UnassignPrivateIpAddresses"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# Create the policy
POLICY_ARN=$(aws iam create-policy --policy-name EKS-CNI-Policy-${CLUSTER_NAME} --policy-document file://vpc-cni-policy.json --query 'Policy.Arn' --output text)
echo "Created policy: ${POLICY_ARN}"

# Create service account for VPC CNI
echo "👤 Creating service account for VPC CNI..."
eksctl create iamserviceaccount \
  --cluster=${CLUSTER_NAME} \
  --namespace=kube-system \
  --name=aws-node \
  --attach-policy-arn=${POLICY_ARN} \
  --override-existing-serviceaccounts \
  --approve

# Delete the aws-node pods to force restart with new permissions
echo "🔄 Restarting aws-node pods..."
kubectl delete pods -n kube-system -l k8s-app=aws-node

# Wait for pods to restart
echo "⏳ Waiting for aws-node pods to restart..."
sleep 30

# Check aws-node pods
echo "🔍 Checking aws-node pods..."
kubectl get pods -n kube-system -l k8s-app=aws-node

# Check node status
echo "🔍 Checking node status..."
kubectl get nodes

# If nodes are still not ready, try reinstalling the CNI plugin
echo "🔧 Reinstalling the CNI plugin..."
kubectl delete daemonset -n kube-system aws-node
sleep 10
kubectl apply -f https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/master/config/master/aws-k8s-cni.yaml

# Wait for the CNI plugin to be reinstalled
echo "⏳ Waiting for CNI plugin to be reinstalled..."
sleep 60

# Check node status again
echo "🔍 Checking node status again..."
kubectl get nodes

echo "✅ CNI plugin fix completed."
echo "If nodes are still not ready, you may need to recycle the nodes by terminating the EC2 instances."
echo "You can do this by scaling the nodegroup down to 0 and then back up:"
echo "aws eks update-nodegroup-config --cluster-name ${CLUSTER_NAME} --nodegroup-name ${NODEGROUP_NAME} --scaling-config desiredSize=0"
echo "# Wait for nodes to terminate"
echo "aws eks update-nodegroup-config --cluster-name ${CLUSTER_NAME} --nodegroup-name ${NODEGROUP_NAME} --scaling-config desiredSize=3"