
#
# Create the VPC
#
resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr
  tags = {
    Name        = "order-system-vpc"
    Environment = "dev"
    project     = "order-system"
  }
}

#
# Create Public Subnet
#
resource "aws_subnet" "public" {
  count             = length(var.public_subnet)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.public_subnet[count.index]
  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  tags = {
    Environment = "dev"
    project     = "order-system"
  }
}


resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Environment = "dev"
    project     = "order-system"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = {
    Environment = "dev"
    project     = "order-system"
  }
}

# # Allocate an Elastic IP for the NAT Gateway
# resource "aws_eip" "nat_eip" {
#   # vpc = true
# }

# Create a NAT Gateway in one of the public subnets
resource "aws_nat_gateway" "nat" {
  allocation_id = "eipalloc-0de6afff8c4533ddb"
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Environment = "dev"
    project     = "order-system"
  }
}


# Create a Route Table for Private Subnets that routes 0.0.0.0/0 via the NAT Gateway
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Environment = "dev"
    project     = "order-system"
  }
}

# data "aws_eip" "existing_nat" {
#   allocation_id = "eipalloc-0de6afff8c4533ddb"
# }

# Associate the Private Route Table with each Private Subnet
resource "aws_route_table_association" "private_assoc" {
  count          = length(var.private_subnet)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "public_association" {
  count          = length(var.public_subnet)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id

}


resource "aws_subnet" "private" {
  count                   = length(var.private_subnet)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = element(var.private_subnet, count.index)
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = false

  tags = {
    Name        = "order-system-private-subnet-${count.index + 1}"
    Environment = "dev"
    project     = "order-system"
  }
}


resource "aws_db_subnet_group" "order_db_subnet_group" {
  name       = "order-system-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id # List of subnet IDs in your VPC that you want to use for your DB
  tags = {
    Environment = "dev"
    project     = "order-system"
  }
}

resource "aws_db_subnet_group" "inventory_db_subnet_group" {
  name       = "inventory-system-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id # List of subnet IDs in your VPC that you want to use for your DB
  tags = {
    Environment = "dev"
    project     = "order-system"
  }
}

resource "aws_security_group" "postgresql-sg" {
  name        = "postgresql-sg"
  description = "Allow PostgreSQL inbound traffic"
  vpc_id      = aws_vpc.this.id

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
    Environment = "dev"
    project     = "order-system"
  }
}


resource "aws_security_group" "fargate_sg" {
  name        = "fargate-sg"
  description = "Allow fargate inbound traffic"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "Allow PostgreSQL access from trusted CIDRs"
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
    Environment = "dev"
    project     = "order-system"
  }
}


resource "aws_security_group" "vpc_endpoint_sg" {
  name        = "vpc-endpoint-sg"
  description = "Security group for VPC endpoints (ECR, etc.)"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "Allow inbound HTTPS traffic from ECS tasks"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    # Option A: Restrict to a specific security group (e.g. ECS tasks SG)
    # security_groups = [aws_security_group.vpc_endpoint_sg.id]
    # Option B: Alternatively, allow from your VPC CIDR (uncomment if needed)
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
    Environment = "dev"
    project     = "order-system"
  }
}



#
# Data source to fetch availability zones
#
data "aws_availability_zones" "available" {
  state = "available"
  names = ["us-east-1b", "us-east-1c"]
}
