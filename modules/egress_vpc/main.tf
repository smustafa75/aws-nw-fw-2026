# Resolve AZ names for subnet placement.
data "aws_availability_zones" "available" { state = "available" }

# ── VPC ───────────────────────────────────────────────────────────────────────
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "egress-vpc" }
}

# ── Internet Gateway ──────────────────────────────────────────────────────────
# Single IGW — NAT Gateways in the public subnets use this for outbound internet.
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "egress-igw" }
}

# ── Public Subnets ────────────────────────────────────────────────────────────
# One per AZ — host the NAT Gateways. map_public_ip_on_launch is false because
# no instances are placed here; only NAT GW EIPs need public IPs.
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  tags = { Name = "egress-public-${count.index + 1}" }
}

# ── TGW Attachment Subnets ────────────────────────────────────────────────────
# /28 subnets — one per AZ, used exclusively for TGW ENIs.
resource "aws_subnet" "tgw" {
  count             = 2
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.tgw_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = { Name = "egress-tgw-${count.index + 1}" }
}

# ── NAT Gateways ──────────────────────────────────────────────────────────────
# One EIP and one NAT GW per AZ — provides AZ-local SNAT for north-south traffic.
# depends_on ensures the IGW is attached before NAT GW creation.
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

# ── Public Route Table ────────────────────────────────────────────────────────
# Default route → IGW for outbound internet traffic from NAT GW.
# Workload CIDR return routes are added from root main.tf after TGW is ready.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "egress-public-rt" }
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
# One route table per AZ — traffic arriving from TGW is sent to the AZ-local NAT GW.
# Separate aws_route resources avoid the inline/external route conflict on re-apply.
resource "aws_route_table" "tgw" {
  count  = 2
  vpc_id = aws_vpc.this.id
  tags   = { Name = "egress-tgw-rt-${count.index + 1}" }
}

resource "aws_route" "tgw_default" {
  count                  = 2
  route_table_id         = aws_route_table.tgw[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat[count.index].id
}

resource "aws_route_table_association" "tgw" {
  count          = 2
  subnet_id      = aws_subnet.tgw[count.index].id
  route_table_id = aws_route_table.tgw[count.index].id
}
