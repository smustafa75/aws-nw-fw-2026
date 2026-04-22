# AWS provider — region and profile are driven by variables.tf / terraform.tfvars.
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

# ── IAM ───────────────────────────────────────────────────────────────────────
# Creates the EC2 instance role with SSM, S3, and CloudWatch permissions.
# The instance profile is consumed by both compute modules.
module "iam" {
  source         = "./iam"
  policy_name    = var.policy_name
  s3_policy      = var.s3_policy
  role_name      = var.role_name
  region_info    = data.aws_region.current.name
  account_id     = data.aws_caller_identity.current.account_id
  partition_info = data.aws_partition.current.partition
}

# ── Firewall Policy ───────────────────────────────────────────────────────────
# Builds the NW-FW policy, stateless forward-all rule group, stateful allow
# rule group (ICMP + TCP 443/80 from 10.0.0.0/8), and the CloudWatch dashboard.
module "firewall" {
  source       = "./modules/firewall"
  project_name = var.project_name
  region       = data.aws_region.current.name
}

# ── Workload VPC A ────────────────────────────────────────────────────────────
# Creates VPC, two workload subnets (one per AZ), two /28 TGW subnets,
# a workload security group, and three SSM interface endpoints.
module "workload_vpc_a" {
  source                = "./modules/workload_vpc"
  name                  = "workload-a"
  vpc_cidr              = var.workload_a_vpc_cidr
  workload_subnet_cidrs = var.workload_a_subnet_cidrs
  tgw_subnet_cidrs      = var.workload_a_tgw_subnet_cidrs
  region                = data.aws_region.current.name
}

# ── Workload VPC B ────────────────────────────────────────────────────────────
module "workload_vpc_b" {
  source                = "./modules/workload_vpc"
  name                  = "workload-b"
  vpc_cidr              = var.workload_b_vpc_cidr
  workload_subnet_cidrs = var.workload_b_subnet_cidrs
  tgw_subnet_cidrs      = var.workload_b_tgw_subnet_cidrs
  region                = data.aws_region.current.name
}

# ── Egress VPC ────────────────────────────────────────────────────────────────
# Creates VPC, IGW, two public subnets, two NAT Gateways (one per AZ),
# two /28 TGW subnets, and per-AZ route tables for TGW → NAT GW traffic.
module "egress_vpc" {
  source              = "./modules/egress_vpc"
  vpc_cidr            = var.egress_vpc_cidr
  public_subnet_cidrs = var.egress_public_subnet_cidrs
  tgw_subnet_cidrs    = var.egress_tgw_subnet_cidrs
}

# ── Transit Gateway + NW-FW ───────────────────────────────────────────────────
# Creates the TGW, three VPC attachments, the NW-FW native TGW attachment,
# three route tables (spoke / firewall / egress), and all TGW routes.
# Also configures NW-FW flow + alert logging to CloudWatch.
module "tgw" {
  source = "./modules/tgw"

  project_name        = var.project_name
  firewall_policy_arn = module.firewall.firewall_policy_arn

  workload_a_vpc_id         = module.workload_vpc_a.vpc_id
  workload_a_tgw_subnet_ids = module.workload_vpc_a.tgw_subnet_ids
  workload_a_cidr           = var.workload_a_vpc_cidr

  workload_b_vpc_id         = module.workload_vpc_b.vpc_id
  workload_b_tgw_subnet_ids = module.workload_vpc_b.tgw_subnet_ids
  workload_b_cidr           = var.workload_b_vpc_cidr

  egress_vpc_id         = module.egress_vpc.vpc_id
  egress_tgw_subnet_ids = module.egress_vpc.tgw_subnet_ids
}

# ── Post-TGW VPC Routes ───────────────────────────────────────────────────────
# These routes are defined at the root level (not inside workload_vpc / egress_vpc)
# to break the circular dependency: VPC modules don't know the TGW ID at creation
# time, and the TGW module needs the VPC/subnet IDs first.

# Workload VPC A — default route sends all traffic to TGW (→ NW-FW inspection).
resource "aws_route" "workload_a_default" {
  route_table_id         = module.workload_vpc_a.workload_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = module.tgw.tgw_id
}

# Workload VPC B — same pattern as VPC A.
resource "aws_route" "workload_b_default" {
  route_table_id         = module.workload_vpc_b.workload_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = module.tgw.tgw_id
}

# Egress VPC TGW subnets — return routes so reply traffic reaches workload VPCs.
# count = 2 because there is one route table per AZ in the egress TGW subnets.
resource "aws_route" "egress_to_workload_a" {
  count                  = 2
  route_table_id         = module.egress_vpc.tgw_route_table_ids[count.index]
  destination_cidr_block = var.workload_a_vpc_cidr
  transit_gateway_id     = module.tgw.tgw_id
}

resource "aws_route" "egress_to_workload_b" {
  count                  = 2
  route_table_id         = module.egress_vpc.tgw_route_table_ids[count.index]
  destination_cidr_block = var.workload_b_vpc_cidr
  transit_gateway_id     = module.tgw.tgw_id
}

# Egress VPC public subnet RT — NAT GW reply traffic must be routed back to TGW
# for workload-bound packets (asymmetric path without these routes would be dropped).
resource "aws_route" "egress_public_to_workload_a" {
  route_table_id         = module.egress_vpc.public_route_table_id
  destination_cidr_block = var.workload_a_vpc_cidr
  transit_gateway_id     = module.tgw.tgw_id
}

resource "aws_route" "egress_public_to_workload_b" {
  route_table_id         = module.egress_vpc.public_route_table_id
  destination_cidr_block = var.workload_b_vpc_cidr
  transit_gateway_id     = module.tgw.tgw_id
}

# ── Compute — Workload VPC A ──────────────────────────────────────────────────
# Two EC2 instances (one per AZ) with SSM access — no SSH key required.
module "compute_a" {
  source            = "./modules/compute"
  name              = "workload-a"
  ami               = var.ami
  instance_type     = var.instance_type
  disk_size         = var.disk_size
  subnet_ids        = module.workload_vpc_a.workload_subnet_ids
  security_group_id = module.workload_vpc_a.workload_sg_id
  instance_profile  = module.iam.iam_instance_profile
  depends_on        = [module.iam]
}

# ── Compute — Workload VPC B ──────────────────────────────────────────────────
module "compute_b" {
  source            = "./modules/compute"
  name              = "workload-b"
  ami               = var.ami
  instance_type     = var.instance_type
  disk_size         = var.disk_size
  subnet_ids        = module.workload_vpc_b.workload_subnet_ids
  security_group_id = module.workload_vpc_b.workload_sg_id
  instance_profile  = module.iam.iam_instance_profile
  depends_on        = [module.iam]
}
