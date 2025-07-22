module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  bootstrap_self_managed_addons = false
  cluster_addons = {
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    # Removed vpc-cni addon to avoid conflicts with existing configuration
  }

  # Optional
  cluster_endpoint_public_access = true

  # Optional: Adds the current caller identity as an administrator via cluster access entry
  enable_cluster_creator_admin_permissions = true

  vpc_id                   = var.vpc_id
  subnet_ids               = var.private_subnets
  control_plane_subnet_ids = var.private_subnets

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    instance_types = var.node_instance_types
  }

  eks_managed_node_groups = {
    main = {
      # Starting on 1.30, AL2023 is the default AMI type for EKS managed node groups
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.node_instance_types

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size
      
      # Add IAM policies for the node group
      iam_role_additional_policies = {
        # Required policies for EKS worker nodes
        AmazonEKSWorkerNodePolicy = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
        AmazonEKS_CNI_Policy = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
        AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
        # Additional policies that might be needed
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }
      
      # Ensure proper tagging for node discovery
      labels = {
        "nodegroup-type" = "main"
      }
      
      # Add taints if needed
      # taints = []
      
      # Ensure proper bootstrap configuration
      bootstrap_extra_args = "--container-runtime containerd --kubelet-extra-args '--max-pods=110'"
      
      # Use the latest AMI release version
      update_config = {
        max_unavailable_percentage = 33 # Allow 33% of nodes to be unavailable during updates
      }
    }
  }

  tags = {
    project     = "order-system"
    Environment = "production"
  }
}
# Get the current AWS region
data "aws_region" "current" {}

# Create an IAM role for the VPC CNI plugin
resource "aws_iam_role" "vpc_cni" {
  name = "${var.cluster_name}-vpc-cni-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${module.eks.oidc_provider}:sub" = "system:serviceaccount:kube-system:aws-node"
            "${module.eks.oidc_provider}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    project     = "order-system"
    Environment = "production"
  }
}

# Attach the required policies to the VPC CNI role
resource "aws_iam_role_policy_attachment" "vpc_cni" {
  role       = aws_iam_role.vpc_cni.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# Create a custom policy for the VPC CNI role with additional permissions
resource "aws_iam_policy" "vpc_cni_custom" {
  name        = "${var.cluster_name}-vpc-cni-custom"
  description = "Custom policy for VPC CNI plugin"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
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
        Resource = "*"
      }
    ]
  })
}

# Attach the custom policy to the VPC CNI role
resource "aws_iam_role_policy_attachment" "vpc_cni_custom" {
  role       = aws_iam_role.vpc_cni.name
  policy_arn = aws_iam_policy.vpc_cni_custom.arn
}

# VPC CNI resources are managed by EKS directly
# Removed kubernetes_service_account and kubernetes_config_map to avoid conflicts