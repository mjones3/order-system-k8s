
output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = local.public_subnets
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = local.private_subnets
}

output "postgresql-sg" {
  description = "Postgresql securit Group"
  value       = aws_security_group.postgresql-sg.id
}

output "fargate_sg" {
  description = "fargate security Group"
  value       = aws_security_group.fargate_sg.id
}

output "vpc_endpoint_sg" {
  description = "vpc endpoint security Group"
  value       = aws_security_group.vpc_endpoint_sg.id
}

output "order_db_subnet_group" {
  description = "Private subnet group"
  value       = data.aws_db_subnet_group.db_subnet_group
}

output "inventory_db_subnet_group" {
  description = "Private subnet group"
  value       = data.aws_db_subnet_group.db_subnet_group
}

output "payment_db_subnet_group" {
  description = "Private subnet group"
  value       = data.aws_db_subnet_group.db_subnet_group
}

output "private_subnets" {
  description = "List of private subnet IDs for the VPC"
  value       = local.private_subnets
}

output "public_subnets" {
  description = "List of public subnet IDs for the VPC"
  value       = local.public_subnets
}

output "vpc_id" {
  description = "VPC id"
  value       = local.vpc_id
}

