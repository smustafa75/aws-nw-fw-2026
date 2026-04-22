provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

# ── IAM ───────────────────────────────────────────────────────────────────────

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

module "firewall" {
  source       = "./modules/firewall"
  project_name = var.project_name
  region       = data.aws_region.current.name
}

# ── Workload VPC A ────────────────────────────────────────────────────────────

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

module "egress_vpc" {
  source              = "./modules/egress_vpc"
  vpc_cidr            = var.egress_vpc_cidr
  public_subnet_cidrs = var.egress_public_subnet_cidrs
  tgw_subnet_cidrs    = var.egress_tgw_subnet_cidrs
}

# ── Transit Gateway + NW-FW ───────────────────────────────────────────────────

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

# ── Post-TGW VPC Routes (added after TGW is ready to break dependency cycle) ──

# Workload VPC A — default route to TGW
resource "aws_route" "workload_a_default" {
  route_table_id         = module.workload_vpc_a.workload_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = module.tgw.tgw_id
}

# Workload VPC B — default route to TGW
resource "aws_route" "workload_b_default" {
  route_table_id         = module.workload_vpc_b.workload_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = module.tgw.tgw_id
}

# Egress VPC TGW subnets — return routes to workload CIDRs via TGW
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

# Egress VPC public subnet RT — NAT GW return traffic must reach TGW for workload CIDRs
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
