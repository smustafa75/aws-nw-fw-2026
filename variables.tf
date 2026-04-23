# ── Provider ──────────────────────────────────────────────────────────────────
# NW-FW native TGW attachment is GA in eu-west-1; change only if the feature
# has been enabled in your target region.
variable "aws_region" { default = "eu-west-1" }

# AWS CLI named profile. Override in terraform.tfvars if not using "default".
variable "aws_profile" { default = "default" }

# Used as a prefix/suffix for all resource names and the CW dashboard.
variable "project_name" { default = "nw-fw-tgw" }

# ── Workload VPC A ────────────────────────────────────────────────────────────
variable "workload_a_vpc_cidr" {}
# Two workload subnets — one per AZ (eu-west-1a, eu-west-1b).
variable "workload_a_subnet_cidrs" { type = list(string) }
# /28 TGW attachment subnets — keep small, only TGW ENIs land here.
variable "workload_a_tgw_subnet_cidrs" { type = list(string) }

# ── Workload VPC B ────────────────────────────────────────────────────────────
variable "workload_b_vpc_cidr" {}
variable "workload_b_subnet_cidrs" { type = list(string) }
variable "workload_b_tgw_subnet_cidrs" { type = list(string) }

# ── Egress VPC ────────────────────────────────────────────────────────────────
variable "egress_vpc_cidr" {}
# Public subnets host the NAT Gateways (one per AZ).
variable "egress_public_subnet_cidrs" { type = list(string) }
# /28 TGW attachment subnets in the egress VPC.
variable "egress_tgw_subnet_cidrs" { type = list(string) }

# ── Compute ───────────────────────────────────────────────────────────────────
# Amazon Linux 2023 AMI — region-specific, set in terraform.tfvars.
variable "ami" {}
variable "instance_type" { default = "t3.micro" }
variable "disk_size" { default = 20 }

# ── IAM ───────────────────────────────────────────────────────────────────────
variable "role_name" {}
variable "policy_name" {}
variable "s3_policy" {}

# ── ALB VPC ───────────────────────────────────────────────────────────────────
# Dedicated VPC for the internet-facing ALB. Keeping ALB in a separate VPC
# forces ALB ↔ EC2 traffic through the TGW and NW-FW for inspection.
variable "alb_vpc_cidr" {}
# /27 minimum per AWS ALB subnet requirements.
variable "alb_public_subnet_cidrs" { type = list(string) }
# /28 TGW attachment subnets in the ALB VPC.
variable "alb_tgw_subnet_cidrs" { type = list(string) }
