resource "aws_vpc" "this" {
  cidr_block           = var.VPC_CIDR
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.PROJECT_NAME}-${var.ENVIRONMENT}-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.PROJECT_NAME}-${var.ENVIRONMENT}-igw"
  }
}

resource "aws_subnet" "public" {
  count = length(var.PUBLIC_SUBNET_CIDRS)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.PUBLIC_SUBNET_CIDRS[count.index]
  availability_zone       = var.AVAILABILITY_ZONES[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.PROJECT_NAME}-${var.ENVIRONMENT}-public-${count.index + 1}"
    Type = "public"
  }
}

resource "aws_subnet" "private" {
  count = length(var.PRIVATE_SUBNET_CIDRS)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.PRIVATE_SUBNET_CIDRS[count.index]
  availability_zone = var.AVAILABILITY_ZONES[count.index]

  tags = {
    Name = "${var.PROJECT_NAME}-${var.ENVIRONMENT}-private-${count.index + 1}"
    Type = "private"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.PROJECT_NAME}-${var.ENVIRONMENT}-public-rt"
  }
}

resource "aws_route_table" "private" {
  count  = var.ENABLE_NAT_GATEWAY ? length(var.PRIVATE_SUBNET_CIDRS) : 0
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[count.index].id
  }

  tags = {
    Name = "${var.PROJECT_NAME}-${var.ENVIRONMENT}-private-rt"
  }
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count = var.ENABLE_NAT_GATEWAY ? length(var.PRIVATE_SUBNET_CIDRS) : 0

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}