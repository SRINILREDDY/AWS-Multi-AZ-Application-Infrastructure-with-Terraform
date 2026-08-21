provider "aws" {
  region = "ap-south-1"
}
#vpc

resource "aws_vpc" "tier-2" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "2-tier"
  }
}

#igw
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.tier-2.id

  tags = {
    Name = "igw"
  }
}

#public subnets

resource "aws_subnet" "public-1" {
  vpc_id                  = aws_vpc.tier-2.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-1"
  }
}

resource "aws_subnet" "public-2" {
  vpc_id                  = aws_vpc.tier-2.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-south-1c"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-2"
  }
}

#route table
resource "aws_route_table" "public-route" {
  vpc_id = aws_vpc.tier-2.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "association-1" {
  subnet_id      = aws_subnet.public-1.id
  route_table_id = aws_route_table.public-route.id
}

resource "aws_route_table_association" "association-2" {
  subnet_id      = aws_subnet.public-2.id
  route_table_id = aws_route_table.public-route.id
}

# private subnets
resource "aws_subnet" "private-1" {
  cidr_block        = "10.0.3.0/24"
  vpc_id            = aws_vpc.tier-2.id
  availability_zone = "ap-south-1b"

  tags = {
    Name = "private-1"
  }
}

resource "aws_subnet" "private-2" {
  cidr_block        = "10.0.4.0/24"
  vpc_id            = aws_vpc.tier-2.id
  availability_zone = "ap-south-1c"

  tags = {
    Name = "private-2"
  }
}

#private route table
resource "aws_route_table" "private-route" {
  vpc_id = aws_vpc.tier-2.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

resource "aws_route_table_association" "association-3" {
  subnet_id      = aws_subnet.private-1.id
  route_table_id = aws_route_table.private-route.id
}

resource "aws_route_table_association" "association-4" {
  subnet_id      = aws_subnet.private-2.id
  route_table_id = aws_route_table.private-route.id
}

# nat gateway
resource "aws_eip" "eip" {
  domain = "vpc"

  tags = {
    Name = "eip"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.public-1.id

  tags = {
    Name = "nat"
  }
}