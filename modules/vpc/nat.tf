resource "aws_eip" "nat" {
  count  = var.ENABLE_NAT_GATEWAY ? length(var.PUBLIC_SUBNET_CIDRS) : 0
  domain = "vpc"

  tags = {
    Name = "${var.PROJECT_NAME}-${var.ENVIRONMENT}-nat-eip-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "this" {
  count = var.ENABLE_NAT_GATEWAY ? length(var.PUBLIC_SUBNET_CIDRS) : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.PROJECT_NAME}-${var.ENVIRONMENT}-nat-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.this]
}

