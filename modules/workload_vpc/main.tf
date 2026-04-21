data "aws_availability_zones" "available" { state = "available" }

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "${var.name}-vpc" }
}

# Workload subnets — one per AZ
resource "aws_subnet" "workload" {
  count             = 2
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.workload_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = { Name = "${var.name}-workload-${count.index + 1}" }
}

# TGW attachment subnet — one per AZ
resource "aws_subnet" "tgw" {
  count             = 2
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.tgw_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = { Name = "${var.name}-tgw-${count.index + 1}" }
}

# Route table for workload subnets — default route to TGW
resource "aws_route_table" "workload" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block         = "0.0.0.0/0"
    transit_gateway_id = var.tgw_id
  }
  tags = { Name = "${var.name}-workload-rt" }
}

resource "aws_route_table_association" "workload" {
  count          = 2
  subnet_id      = aws_subnet.workload[count.index].id
  route_table_id = aws_route_table.workload.id
}

# Security group for workload instances
resource "aws_security_group" "workload" {
  name        = "${var.name}-workload-sg"
  description = "Workload instances SG"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.0.0.0/8"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.name}-workload-sg" }
}

# VPC endpoints for SSM (no internet access needed)
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.ssm"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = aws_subnet.workload[*].id
  security_group_ids  = [aws_security_group.workload.id]
  tags = { Name = "${var.name}-ssm-ep" }
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = aws_subnet.workload[*].id
  security_group_ids  = [aws_security_group.workload.id]
  tags = { Name = "${var.name}-ssmmessages-ep" }
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = aws_subnet.workload[*].id
  security_group_ids  = [aws_security_group.workload.id]
  tags = { Name = "${var.name}-ec2messages-ep" }
}
