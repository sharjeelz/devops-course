# Linkly's network (module 7): Module 6, lesson 2 as code. A VPC with public subnets in several
# Availability Zones (Module 8 adds EKS to them), an internet gateway and a route to it.
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = var.name }
}

resource "aws_subnet" "public" {
  count                   = var.az_count
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.cidr, 8, count.index + 1) # 10.0.1.0/24, 10.0.2.0/24, ...
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags                    = merge({ Name = "${var.name}-public-${count.index + 1}" }, var.public_subnet_tags)
}

# Private subnets (module 8): for things that must never be reachable from the internet, like the
# database. Their route table has no default route at all: no internet gateway, no NAT.
resource "aws_subnet" "private" {
  count                   = var.private_subnets ? var.az_count : 0
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.cidr, 8, count.index + 101) # 10.0.101.0/24, 10.0.102.0/24, ...
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  tags                    = { Name = "${var.name}-private-${count.index + 1}" }
}

resource "aws_route_table" "private" {
  count  = var.private_subnets ? 1 : 0
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-private" }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[0].id
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = var.name }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = { Name = "${var.name}-public" }
}

resource "aws_route_table_association" "public" {
  count          = var.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
