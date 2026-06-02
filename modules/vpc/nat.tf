resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? length(var.public_subnet_cidrs) : 0
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-${var.environment}-nat-eip-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "this" {
  count = var.enable_nat_gateway ? length(var.public_subnet_cidrs) : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.project_name}-${var.environment}-nat-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.this]
}

