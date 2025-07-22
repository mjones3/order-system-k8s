variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
}

variable "public_subnet" {
  type        = list(string)
  description = "List of CIDRs for public subnets"
}

variable "private_subnet" {
  type        = list(string)
  description = "List of CIDRs for private subnets"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}

variable "db_subnet" {
  type        = list(string)
  description = "List of CIDRs for database subnets"
  default     = ["172.2.5.0/24", "172.2.6.0/24"]
}
