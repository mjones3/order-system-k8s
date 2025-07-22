resource "aws_db_instance" "this" {
  allocated_storage = var.allocated_storage
  storage_type      = "gp2"
  engine            = "postgres"
  engine_version    = var.engine_version
  instance_class    = var.instance_class
  db_name           = var.db_name
  username          = var.username
  password          = var.password
  # parameter_group_name   = var.parameter_group_name
  skip_final_snapshot    = true
  publicly_accessible    = var.publicly_accessible
  vpc_security_group_ids = var.vpc_security_group_ids
  db_subnet_group_name   = var.db_subnet_group_name
  multi_az               = var.multi_az
  tags                   = var.tags
}


resource "aws_db_subnet_group" "order_db_subnet_group" {
  name       = "order-db-subnet-group"
  subnet_ids = var.private_subnets
  tags       = var.tags
}
