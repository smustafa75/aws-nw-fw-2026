# Egress VPC CIDR (e.g. 10.0.0.0/16).
variable "vpc_cidr" {}

# Two public subnet CIDRs — one per AZ, host the NAT Gateways and EIPs.
variable "public_subnet_cidrs" { type = list(string) }

# Two /28 TGW attachment subnet CIDRs — one per AZ, used exclusively for TGW ENIs.
variable "tgw_subnet_cidrs" { type = list(string) }
