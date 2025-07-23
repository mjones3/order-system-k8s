provider "aws" {
  region = "us-east-1"

  # Increase timeout for provider initialization
  skip_metadata_api_check     = false
  skip_region_validation      = false
  skip_credentials_validation = false
}

# Configure Kubernetes provider
provider "kubernetes" {
  host                   = try(module.eks.cluster_endpoint, "")
  cluster_ca_certificate = try(base64decode(module.eks.cluster_certificate_authority_data), "")

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", "order-system-cluster"]
  }
}

# Configure Helm provider
provider "helm" {
  kubernetes {
    host                   = try(module.eks.cluster_endpoint, "")
    cluster_ca_certificate = try(base64decode(module.eks.cluster_certificate_authority_data), "")

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", "order-system-cluster"]
    }
  }
}

# Network module (using existing VPC and subnets)
module "network" {
  source   = "./modules/network"
  vpc_cidr = "172.2.0.0/16" # This is just a reference, the actual VPC CIDR is fetched from the data source
  # Define new subnets that don't conflict with existing ones
  public_subnet  = ["172.2.10.0/24", "172.2.11.0/24"]
  private_subnet = ["172.2.12.0/24", "172.2.13.0/24"]
  db_subnet      = ["172.2.14.0/24", "172.2.15.0/24"]
  tags = {
    Environment = "production"
    project     = "order-system"
  }
}

# EKS Cluster
module "eks" {
  source = "./modules/eks"

  vpc_id          = module.network.vpc_id
  private_subnets = module.network.private_subnets

  cluster_name        = "order-system-cluster"
  cluster_version     = "1.31"
  node_instance_types = ["t3.medium"]
  node_desired_size   = 3
  node_max_size       = 10
  node_min_size       = 2
}

# AWS Load Balancer Controller
module "alb_controller" {
  source = "./modules/alb-controller"

  cluster_name      = module.eks.cluster_name
  oidc_provider     = module.eks.oidc_provider
  oidc_provider_arn = module.eks.oidc_provider_arn
  vpc_id            = module.network.vpc_id
  region            = "us-east-1"

  depends_on = [module.eks]
}

# ECR repositories (reusing existing)
module "ecr_repo" {
  source                      = "./modules/ecr_repo"
  repository_name             = "order-system-repo"
  ecs_task_execution_role_arn = module.iam.ecs_task_execution_role_arn
  vpc_id                      = module.network.vpc_id
  vpc_endpoint_sg             = module.network.vpc_endpoint_sg
  private_subnets             = module.network.private_subnets
}

# IAM module (reusing existing)
module "iam" {
  source                                    = "./modules/iam"
  aws_lambda_function_order_service_arn     = module.lambda.aws_lambda_function_order_service_arn
  aws_lambda_function_inventory_service_arn = module.lambda.aws_lambda_function_inventory_service_arn
  aws_lambda_function_payment_service_arn   = module.lambda.aws_lambda_function_payment_service_arn
  aws_lambda_function_cancel_order_arn      = module.lambda.aws_lambda_function_cancel_order_arn
  aws_lambda_function_release_inventory_arn = module.lambda.aws_lambda_function_release_inventory_arn
}

# Lambda functions (for Step Functions integration)
module "lambda" {
  source                         = "./modules/lambda"
  aws_iam_role_sfn_role_arn      = module.iam.aws_iam_role_sfn_role_arn
  lambda_exec_role_arn           = module.iam.lambda_exec_role_arn
  aws_lambda_assume_role_arn     = module.iam.aws_lambda_assume_role_arn
  api_endpoint_orders            = module.eks_order_service.alb_endpoint
  api_endpoint_inventory         = module.eks_inventory_service.alb_endpoint
  api_endpoint_payment           = module.eks_payment_service.alb_endpoint
  api_endpoint_cancel_order      = "${module.eks_order_service.alb_endpoint}/cancel"
  api_endpoint_release_inventory = "${module.eks_inventory_service.alb_endpoint}/release"
}

# Step Functions API
module "api-sfn" {
  source                           = "./modules/api-sfn"
  aws_sfn_state_machine_order_saga = module.lambda.aws_sfn_state_machine_order_saga
}

# RDS Databases for each service
module "order_service_db" {
  source                 = "./modules/services/order_service/db"
  allocated_storage      = 20
  engine_version         = "17.2"
  instance_class         = "db.t3.micro"
  db_name                = "orderdb"
  username               = "orderuser"
  password               = var.db_password
  task_role_arn          = ""
  publicly_accessible    = false
  vpc_security_group_ids = [module.network.postgresql-sg]
  db_subnet_group_name   = module.network.order_db_subnet_group.name
  private_subnets        = module.network.private_subnets
  multi_az               = false
  tags = {
    Environment = "production"
    Service     = "order-service"
    project     = "order-system"
  }
}

module "inventory_service_db" {
  source                 = "./modules/services/inventory_service/db"
  allocated_storage      = 20
  engine_version         = "17.2"
  instance_class         = "db.t3.micro"
  db_name                = "inventorydb"
  username               = "inventoryuser"
  password               = "password123" # Updated password
  task_role_arn          = ""
  publicly_accessible    = false
  vpc_security_group_ids = [module.network.postgresql-sg]
  db_subnet_group_name   = module.network.inventory_db_subnet_group.name
  private_subnets        = module.network.private_subnets
  multi_az               = false
  tags = {
    Environment = "production"
    Service     = "inventory-service"
    project     = "order-system"
  }
}

module "payment_service_db" {
  source                 = "./modules/services/payment_service/db"
  allocated_storage      = 20
  engine_version         = "17.4"
  instance_class         = "db.t3.micro"
  db_name                = "paymentdb"
  username               = "paymentuser"
  password               = "password123" # Updated password
  task_role_arn          = ""
  publicly_accessible    = false
  vpc_security_group_ids = [module.network.postgresql-sg]
  db_subnet_group_name   = module.network.payment_db_subnet_group.name
  private_subnets        = module.network.private_subnets
  multi_az               = false
  tags = {
    Environment = "production"
    Service     = "payment-service"
    project     = "order-system"
  }
}

# EKS Service Deployments
module "eks_order_service" {
  source = "./modules/eks-services/order-service"

  order_service_image = var.order_service_image
  db_name             = "orderdb"
  db_username         = "orderuser"
  db_password         = var.db_password
  rds_endpoint        = module.order_service_db.rds_endpoint

  replica_count = 2
  min_replicas  = 2
  max_replicas  = 10

  depends_on = [module.eks, module.alb_controller]
}

module "eks_inventory_service" {
  source = "./modules/eks-services/inventory-service"

  inventory_service_image = var.inventory_service_image
  db_name                 = "inventorydb"
  db_username             = "inventoryuser"
  db_password             = "password123" # Updated password
  rds_endpoint            = module.inventory_service_db.rds_endpoint

  replica_count = 2
  min_replicas  = 2
  max_replicas  = 10

  depends_on = [module.eks, module.alb_controller]
}

module "eks_payment_service" {
  source = "./modules/eks-services/payment-service"

  payment_service_image = var.payment_service_image
  db_name               = "paymentdb"
  db_username           = "paymentuser"
  db_password           = "password123" # Updated password
  rds_endpoint          = module.payment_service_db.rds_endpoint

  replica_count = 2
  min_replicas  = 2
  max_replicas  = 10

  depends_on = [module.eks, module.alb_controller]
}
