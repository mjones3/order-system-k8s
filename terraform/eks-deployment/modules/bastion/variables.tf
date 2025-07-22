variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "public_subnet_id" {
  description = "A public subnet ID where the bastion will reside"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into the bastion"
  type        = string
  default     = "96.227.71.0/24"   
}

variable "ssh_key_name" {
  description = "Name of the EC2 Key Pair for SSH access"
  type        = string
}