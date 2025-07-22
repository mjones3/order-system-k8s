
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.61.0"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-1"
}


module "network" {
  source         = "./modules/network"
  vpc_cidr       = "172.1.0.0/16"
  public_subnet  = ["172.1.1.0/24", "172.1.2.0/24"]
  private_subnet = ["172.1.3.0/24", "172.1.4.0/24"]
  tags = {
    Environment = "dev"
    project     = "order-system"
  }
}

module "api-sfn" {
  source                           = "./modules/api-sfn"
  aws_sfn_state_machine_order_saga = module.lambda.aws_sfn_state_machine_order_saga
}



module "lambda" {
  source                         = "./modules/lambda"
  aws_iam_role_sfn_role_arn      = module.iam.aws_iam_role_sfn_role_arn
  lambda_exec_role_arn           = module.iam.lambda_exec_role_arn
  aws_lambda_assume_role_arn     = module.iam.aws_lambda_assume_role_arn
  api_endpoint_orders            = module.ecs_order_service.order_lb_dns
  api_endpoint_inventory         = module.ecs_inventory_service.inventory_lb_dns
  api_endpoint_payment           = module.ecs_payment_service.payment_lb_dns
  api_endpoint_cancel_order      = module.ecs_order_service.order_lb_dns
  api_endpoint_release_inventory = module.ecs_inventory_service.inventory_lb_dns

}

module "iam" {
  source                                    = "./modules/iam"
  aws_lambda_function_order_service_arn     = module.lambda.aws_lambda_function_order_service_arn
  aws_lambda_function_inventory_service_arn = module.lambda.aws_lambda_function_inventory_service_arn
  aws_lambda_function_payment_service_arn   = module.lambda.aws_lambda_function_payment_service_arn
  aws_lambda_function_cancel_order_arn      = module.lambda.aws_lambda_function_cancel_order_arn
  aws_lambda_function_release_inventory_arn = module.lambda.aws_lambda_function_release_inventory_arn
}

module "sqs" {
  source = "./modules/sqs"
}

module "ecr_repo" {
  source                      = "./modules/ecr_repo"
  repository_name             = "order-system-repo"
  ecs_task_execution_role_arn = module.iam.ecs_task_execution_role_arn
  vpc_id                      = module.network.vpc_id
  vpc_endpoint_sg             = module.network.vpc_endpoint_sg
  private_subnets             = module.network.private_subnets

}

module "ecs" {
  source          = "./modules/ecs"
  vpc_id          = module.network.vpc_id
  vpc_endpoint_sg = module.network.vpc_endpoint_sg
}

module "cognito" {
  source = "./modules/cognito"
}

module "ecs_order_service" {
  source              = "./modules/services/order_service"
  public_subnets      = module.network.public_subnets
  private_subnets     = module.network.private_subnets
  execution_role_arn  = module.iam.ecs_task_execution_role_arn
  order_service_image = var.order_service_image
  fargate_cluster     = module.ecs.fargate_cluster
  fargate_sg          = module.network.fargate_sg
  vpc_endpoint_sg     = module.network.vpc_endpoint_sg
  vpc_id              = module.network.vpc_id
  rds_endpoint        = module.order_service_db.rds_endpoint
  db_name             = "orderdb"
  db_username         = "orderuser"
  db_password         = "secretpassword"
}

module "order_service_db" {
  source            = "./modules/services/order_service/db"
  allocated_storage = 10
  #   storage_type      = "gp2"
  engine_version = "17.2"
  instance_class = "db.t3.micro"
  db_name        = "orderdb"
  username       = "orderuser"
  password       = "secretpassword"
  task_role_arn  = ""
  #   parameter_group_name   = "default.postgres13"
  publicly_accessible    = false
  vpc_security_group_ids = [module.network.postgresql-sg]
  db_subnet_group_name   = module.network.order_db_subnet_group.name
  private_subnets        = module.network.private_subnets
  multi_az               = false
  tags = {
    Environment = "dev"
    Service     = "order-service"
    project     = "order-system"
  }
}


module "ecs_inventory_service" {
  source                  = "./modules/services/inventory_service"
  public_subnets          = module.network.public_subnets
  private_subnets         = module.network.private_subnets
  execution_role_arn      = module.iam.ecs_task_execution_role_arn
  inventory_service_image = var.inventory_service_image
  fargate_cluster         = module.ecs.fargate_cluster
  fargate_sg              = module.network.fargate_sg
  vpc_endpoint_sg         = module.network.vpc_endpoint_sg
  vpc_id                  = module.network.vpc_id
  rds_endpoint            = module.inventory_service_db.rds_endpoint
  db_name                 = "inventorydb"
  db_username             = "inventoryuser"
  db_password             = "secretpassword"
}

module "inventory_service_db" {
  source            = "./modules/services/inventory_service/db"
  allocated_storage = 10
  #   storage_type      = "gp2"
  engine_version = "17.2"
  instance_class = "db.t3.micro"
  db_name        = "inventorydb"
  username       = "inventoryuser"
  password       = "secretpassword"
  task_role_arn  = ""
  #   parameter_group_name   = "default.postgres13"
  publicly_accessible    = false
  vpc_security_group_ids = [module.network.postgresql-sg]
  db_subnet_group_name   = module.network.inventory_db_subnet_group.name
  private_subnets        = module.network.private_subnets
  multi_az               = false
  tags = {
    Environment = "dev"
    Service     = "inventory-service"
    project     = "order-system"
  }
}

module "ecs_payment_service" {
  source                = "./modules/services/payment_service"
  public_subnets        = module.network.public_subnets
  private_subnets       = module.network.private_subnets
  execution_role_arn    = module.iam.ecs_task_execution_role_arn
  payment_service_image = var.payment_service_image
  fargate_cluster       = module.ecs.fargate_cluster
  fargate_sg            = module.network.fargate_sg
  vpc_endpoint_sg       = module.network.vpc_endpoint_sg
  vpc_id                = module.network.vpc_id
  rds_endpoint          = module.payment_service_db.rds_endpoint
  db_name               = "paymentdb"
  db_username           = "paymentuser"
  db_password           = "secretpassword"
}

module "payment_service_db" {
  source            = "./modules/services/payment_service/db"
  allocated_storage = 10
  #   storage_type      = "gp2"
  engine_version = "17.2"
  instance_class = "db.t3.micro"
  db_name        = "paymentdb"
  username       = "paymentuser"
  password       = "secretpassword"
  task_role_arn  = ""
  #   parameter_group_name   = "default.postgres13"
  publicly_accessible    = false
  vpc_security_group_ids = [module.network.postgresql-sg]
  db_subnet_group_name   = module.network.payment_db_subnet_group.name
  private_subnets        = module.network.private_subnets
  multi_az               = false
  tags = {
    Environment = "dev"
    Service     = "payment-service"
    project     = "order-system"
  }
}
