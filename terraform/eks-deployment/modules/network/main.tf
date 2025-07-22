#
# Use existing VPC instead of creating a new one
#
data "aws_vpc" "existing" {
  id = "vpc-024c0c2f1ea047c09"  # The specific VPC where databases are deployed
}

# Reference to the existing VPC
locals {
  vpc_id   = data.aws_vpc.existing.id
  vpc_cidr = data.aws_vpc.existing.cidr_block
}

#
# Data source to fetch availability zones
#
data "aws_availability_zones" "available" {
  state         = "available"
  exclude_names = ["us-east-1a"]
}

#
# Internet Gateway
#
resource "aws_internet_gateway" "this" {
  vpc_id = local.vpc_id
  tags = {
    Environment = "dev"
    project     = "order-system"
  }
}

# Get all subnets in the VPC
data "aws_subnets" "all" {
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
}

# Get subnet details
data "aws_subnet" "all" {
  for_each = toset(data.aws_subnets.all.ids)
  id       = each.value
}

# Create local variables to organize subnets by type
locals {
  public_subnets = [
    for id, subnet in data.aws_subnet.all : subnet.id
    if contains(keys(subnet.tags), "Type") && subnet.tags["Type"] == "public"
  ]
  
  private_subnets = [
    for id, subnet in data.aws_subnet.all : subnet.id
    if contains(keys(subnet.tags), "Type") && subnet.tags["Type"] == "private"
  ]
  
  database_subnets = [
    for id, subnet in data.aws_subnet.all : subnet.id
    if contains(keys(subnet.tags), "Type") && subnet.tags["Type"] == "database"
  ]
}

#
# Public Route Table
#
resource "aws_route_table" "public" {
  vpc_id = local.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name        = "Public Route Table"
    Environment = "dev"
    project     = "order-system"
  }
}

#
# Private Route Table
#
resource "aws_route_table" "private_rt" {
  vpc_id = local.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  
  tags = {
    Name        = "Private Route Table"
    Environment = "dev"
    project     = "order-system"
  }
}

#
# Database Route Table (optional - can use private RT)
#
resource "aws_route_table" "db" {
  vpc_id = local.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name        = "DB Route Table"
    Environment = "dev"
    project     = "order-system"
  }
}

#
# NAT Gateway
#
resource "aws_nat_gateway" "nat" {
  allocation_id = "eipalloc-0de6afff8c4533ddb"
  subnet_id     = local.public_subnets[0]
  depends_on    = [aws_internet_gateway.this]

  tags = {
    Name        = "NAT Gateway"
    Environment = "dev"
    project     = "order-system"
  }
}

#
# Route Table Associations
#
resource "aws_route_table_association" "public_association" {
  count          = length(local.public_subnets)
  subnet_id      = local.public_subnets[count.index]
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_assoc" {
  count          = length(local.private_subnets)
  subnet_id      = local.private_subnets[count.index]
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "db_assoc" {
  count          = length(local.database_subnets)
  subnet_id      = local.database_subnets[count.index]
  route_table_id = aws_route_table.db.id
}

#
# DB Subnet Groups
#
# Use existing DB subnet group for all services
data "aws_db_subnet_group" "db_subnet_group" {
  name = "order-system-db-subnet-group"
}

#
# Security Groups
#
resource "aws_security_group" "postgresql-sg" {
  name        = "postgresql-sg"
  description = "Allow PostgreSQL inbound traffic"
  vpc_id      = local.vpc_id

  ingress {
    description = "Allow PostgreSQL access from trusted CIDRs"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "PostgreSQL Security Group"
    Environment = "dev"
    project     = "order-system"
  }
}

resource "aws_security_group" "fargate_sg" {
  name        = "fargate-sg"
  description = "Allow fargate inbound traffic"
  vpc_id      = local.vpc_id

  ingress {
    description = "Allow application access from VPC"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "Fargate Security Group"
    Environment = "dev"
    project     = "order-system"
  }
}

resource "aws_security_group" "vpc_endpoint_sg" {
  name        = "vpc-endpoint-sg"
  description = "Security group for VPC endpoints (ECR, etc.)"
  vpc_id      = local.vpc_id

  ingress {
    description = "Allow inbound HTTPS traffic from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "VPC Endpoint Security Group"
    Environment = "dev"
    project     = "order-system"
  }
}