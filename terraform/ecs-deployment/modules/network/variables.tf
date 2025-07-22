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
