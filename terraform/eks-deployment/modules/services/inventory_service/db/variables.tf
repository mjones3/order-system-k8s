variable "allocated_storage" {
  description = "Allocated storage (in GB) for the RDS instance."
  type        = number
  default     = 20
}

variable "engine_version" {
  description = "PostgreSQL engine version."
  type        = string
  default     = "13.7"
}

variable "instance_class" {
  description = "RDS instance class." 
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Initial database name."
  type        = string
}

variable "username" {
  description = "Database master username."
  type        = string
}

variable "password" {
  description = "Database master password."
  type        = string
  sensitive   = true
}

variable "parameter_group_name" {
  description = "Parameter group name for the DB instance."
  type        = string
  default     = "default.postgres13"
}

variable "publicly_accessible" {
  description = "Whether the RDS instance should be publicly accessible."
  type        = bool
  default     = false
}

variable "vpc_security_group_ids" {
  description = "List of VPC security group IDs to associate with the RDS instance."
  type        = list(string)
}

variable "db_subnet_group_name" {
  description = "The name of the DB subnet group."
  type        = string
}

variable "multi_az" {
  description = "Deploy the RDS instance in multiple AZs."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to the RDS instance."
  type        = map(string)
  default     = {}
}

variable "private_subnets" {
  description = "List of VPC security group IDs to associate with the RDS instance."
  type        = list(string)
}

variable "task_role_arn" {
  description = "The ARN of task role ARN"
  type        = string
}

