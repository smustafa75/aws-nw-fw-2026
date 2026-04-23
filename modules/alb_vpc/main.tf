data "aws_availability_zones" "available" { state = "available" }

# ── VPC ───────────────────────────────────────────────────────────────────────
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "alb-vpc" }
}

# ── Internet Gateway ──────────────────────────────────────────────────────────
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "alb-igw" }
}

# ── Public Subnets ────────────────────────────────────────────────────────────
# /27 minimum for ALB — one per AZ, host ALB nodes.
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  tags = { Name = "alb-public-${count.index + 1}" }
}

# ── TGW Attachment Subnets ────────────────────────────────────────────────────
# /28 subnets — one per AZ, used exclusively for TGW ENIs.
resource "aws_subnet" "tgw" {
  count             = 2
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.tgw_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = { Name = "alb-tgw-${count.index + 1}" }
}

# ── Public Route Table ────────────────────────────────────────────────────────
# Default route → IGW for outbound internet traffic from ALB.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "alb-public-rt" }
}

resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ── TGW Subnet Route Tables ───────────────────────────────────────────────────
# One route table per AZ — traffic arriving from TGW destined for workload VPCs.
# Default route added from root main.tf after TGW is ready.
resource "aws_route_table" "tgw" {
  count  = 2
  vpc_id = aws_vpc.this.id
  tags   = { Name = "alb-tgw-rt-${count.index + 1}" }
}

resource "aws_route_table_association" "tgw" {
  count          = 2
  subnet_id      = aws_subnet.tgw[count.index].id
  route_table_id = aws_route_table.tgw[count.index].id
}

# ── ALB Security Group ────────────────────────────────────────────────────────
# Ingress: HTTP from internet. Egress: HTTP to RFC-1918 (workload VPCs).
resource "aws_security_group" "alb" {
  name        = "alb-sg"
  description = "ALB security group"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "HTTP to workload VPCs"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }
  tags = { Name = "alb-sg" }
}
