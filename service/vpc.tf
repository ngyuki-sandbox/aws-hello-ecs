////////////////////////////////////////////////////////////////////////////////
// VPC

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "${var.tag}-vpc"
  }
}

locals {
  availability_zones = [
    "ap-northeast-1a",
    "ap-northeast-1c",
  ]
}

resource "aws_subnet" "front" {
  count             = length(local.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone = local.availability_zones[count.index]

  tags = {
    Name = "${var.tag}-front"
  }
}

resource "aws_subnet" "back" {
  count             = length(local.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + length(local.availability_zones))
  availability_zone = local.availability_zones[count.index]

  tags = {
    Name = "${var.tag}-back"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.tag}-igw"
  }
}

resource "aws_eip" "nat" {
  count = length(local.availability_zones)
  vpc   = true

  tags = {
    Name = "${var.tag}-nat"
  }
}

resource "aws_nat_gateway" "ngw" {
  count         = length(local.availability_zones)
  subnet_id     = element(aws_subnet.front.*.id, count.index)
  allocation_id = element(aws_eip.nat.*.id, count.index)

  tags = {
    Name = "${var.tag}-ngw"
  }
}

resource "aws_route" "main" {
  route_table_id         = aws_vpc.main.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table" "back" {
  count  = length(local.availability_zones)
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.tag}-back"
  }
}

resource "aws_route" "back" {
  count                  = length(local.availability_zones)
  route_table_id         = element(aws_route_table.back.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element(aws_nat_gateway.ngw.*.id, count.index)
}

resource "aws_route_table_association" "back" {
  count          = length(local.availability_zones)
  subnet_id      = element(aws_subnet.back.*.id, count.index)
  route_table_id = element(aws_route_table.back.*.id, count.index)
}

resource "aws_security_group" "front" {
  name        = "${var.tag}-front"
  description = "${var.tag}-front"
  vpc_id      = aws_vpc.main.id

  # http
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # local
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = -1
    self      = true
  }

  # outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "back" {
  name        = "${var.tag}-back"
  description = "${var.tag}-back"
  vpc_id      = aws_vpc.main.id

  # front
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.front.id]
  }

  # local
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = -1
    self      = true
  }

  # outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}
