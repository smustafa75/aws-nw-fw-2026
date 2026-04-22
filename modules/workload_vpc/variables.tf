# Logical name prefix (e.g. "workload-a" or "workload-b") — used in resource tags.
variable "name" {}

# VPC CIDR block (e.g. 10.1.0.0/16).
variable "vpc_cidr" {}

# Two workload subnet CIDRs — one per AZ (eu-west-1a, eu-west-1b).
variable "workload_subnet_cidrs" { type = list(string) }

# Two /28 TGW attachment subnet CIDRs — keep small, only TGW ENIs land here.
variable "tgw_subnet_cidrs" { type = list(string) }

# AWS region — used to construct SSM VPC endpoint service names.
variable "region" {}
