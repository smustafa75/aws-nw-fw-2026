data "aws_availability_zones" "available" { state = "available" }

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "egress-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "egress-igw" }
}

# Public subnets — NAT GW, one per AZ
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  tags = { Name = "egress-public-${count.index + 1}" }
}

# TGW attachment subnets — one per AZ
resource "aws_subnet" "tgw" {
  count             = 2
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.tgw_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = { Name = "egress-tgw-${count.index + 1}" }
}

# EIPs and NAT Gateways — one per AZ
resource "aws_eip" "nat" {
  count  = 2
  domain = "vpc"
  tags   = { Name = "egress-nat-eip-${count.index + 1}" }
}

resource "aws_nat_gateway" "nat" {
  count         = 2
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags          = { Name = "egress-natgw-${count.index + 1}" }
  depends_on    = [aws_internet_gateway.igw]
}

# Public route table — IGW for outbound
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "egress-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# TGW subnet route tables — traffic from TGW goes to NAT GW for SNAT
resource "aws_route_table" "tgw" {
  count  = 2
  vpc_id = aws_vpc.this.id
  tags   = { Name = "egress-tgw-rt-${count.index + 1}" }
}

# Separate aws_route to avoid inline/external route conflict on re-apply
resource "aws_route" "tgw_default" {
  count          = 2
  route_table_id = aws_route_table.tgw[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.nat[count.index].id
}

resource "aws_route_table_association" "tgw" {
  count          = 2
  subnet_id      = aws_subnet.tgw[count.index].id
  route_table_id = aws_route_table.tgw[count.index].id
}
