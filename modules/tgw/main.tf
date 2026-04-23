# Resolve AZ IDs for the NW-FW availability_zone_mapping blocks.
data "aws_availability_zones" "available" { state = "available" }

# ── Transit Gateway ───────────────────────────────────────────────────────────
# Default route table association/propagation disabled — all routing is explicit
# via the three custom route tables (spoke / firewall / egress).
resource "aws_ec2_transit_gateway" "tgw" {
  description                     = "TGW - ${var.project_name}"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  auto_accept_shared_attachments  = "enable"
  tags = { Name = "TGW-${var.project_name}" }
}

# ── TGW VPC Attachments ───────────────────────────────────────────────────────
# Each attachment uses the dedicated /28 TGW subnets (one per AZ).
# Default RT association/propagation disabled — handled by explicit associations below.

resource "aws_ec2_transit_gateway_vpc_attachment" "workload_a" {
  transit_gateway_id                              = aws_ec2_transit_gateway.tgw.id
  vpc_id                                          = var.workload_a_vpc_id
  subnet_ids                                      = var.workload_a_tgw_subnet_ids
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  tags = { Name = "TGW-attach-workload-a" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "workload_b" {
  transit_gateway_id                              = aws_ec2_transit_gateway.tgw.id
  vpc_id                                          = var.workload_b_vpc_id
  subnet_ids                                      = var.workload_b_tgw_subnet_ids
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  tags = { Name = "TGW-attach-workload-b" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "egress" {
  transit_gateway_id                              = aws_ec2_transit_gateway.tgw.id
  vpc_id                                          = var.egress_vpc_id
  subnet_ids                                      = var.egress_tgw_subnet_ids
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  tags = { Name = "TGW-attach-egress" }
}

# ── ALB VPC Attachment ────────────────────────────────────────────────────────
# 4th spoke — ALB VPC. Traffic between ALB and workload VPCs crosses TGW,
# ensuring NW-FW inspects every ALB ↔ EC2 request in both directions.
resource "aws_ec2_transit_gateway_vpc_attachment" "alb" {
  transit_gateway_id                              = aws_ec2_transit_gateway.tgw.id
  vpc_id                                          = var.alb_vpc_id
  subnet_ids                                      = var.alb_tgw_subnet_ids
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  tags = { Name = "TGW-attach-alb" }
}

# ── NW-FW Native TGW Attachment ───────────────────────────────────────────────
# This is the GA feature (eu-west-1) — no inspection VPC needed.
# The firewall is attached directly to the TGW; AWS manages the ENIs internally.
# Two AZ mappings ensure HA across eu-west-1a and eu-west-1b.
resource "aws_networkfirewall_firewall" "fw" {
  name                = "fw-${var.project_name}"
  firewall_policy_arn = var.firewall_policy_arn
  transit_gateway_id  = aws_ec2_transit_gateway.tgw.id

  availability_zone_mapping {
    availability_zone_id = data.aws_availability_zones.available.zone_ids[0]
  }
  availability_zone_mapping {
    availability_zone_id = data.aws_availability_zones.available.zone_ids[1]
  }

  tags = { Name = "NW-FW-${var.project_name}" }
}

# ── TGW Route Tables ──────────────────────────────────────────────────────────
# spoke-rt    → associated with Workload A & B attachments
# firewall-rt → associated with the NW-FW attachment
# egress-rt   → associated with the Egress VPC attachment

resource "aws_ec2_transit_gateway_route_table" "spoke" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  tags = { Name = "TGW-RT-spoke" }
}

resource "aws_ec2_transit_gateway_route_table" "firewall" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  tags = { Name = "TGW-RT-firewall" }
}

resource "aws_ec2_transit_gateway_route_table" "egress" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  tags = { Name = "TGW-RT-egress" }
}

# ── RT Associations ───────────────────────────────────────────────────────────
# Each attachment is associated with exactly one route table.

resource "aws_ec2_transit_gateway_route_table_association" "workload_a" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.workload_a.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke.id
}

resource "aws_ec2_transit_gateway_route_table_association" "workload_b" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.workload_b.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke.id
}

# NW-FW attachment ID is read from the firewall status block after creation.
resource "aws_ec2_transit_gateway_route_table_association" "fw" {
  transit_gateway_attachment_id  = aws_networkfirewall_firewall.fw.firewall_status[0].transit_gateway_attachment_sync_states[0].attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.firewall.id
}

resource "aws_ec2_transit_gateway_route_table_association" "egress" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.egress.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.egress.id
}

# ALB VPC → spoke-rt (same as workload VPCs — all traffic goes to NW-FW first).
resource "aws_ec2_transit_gateway_route_table_association" "alb" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.alb.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke.id
}

# ── Local: NW-FW attachment ID ────────────────────────────────────────────────
# Extracted once and reused across all route resources to avoid repetition.
locals {
  fw_attachment_id = aws_networkfirewall_firewall.fw.firewall_status[0].transit_gateway_attachment_sync_states[0].attachment_id
}

# ── Spoke RT Routes ───────────────────────────────────────────────────────────
# All traffic from workload VPCs (east-west and north-south) is sent to NW-FW first.

# Default route — catches internet-bound and any unknown destinations.
resource "aws_ec2_transit_gateway_route" "spoke_default" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = local.fw_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke.id
}

# Explicit routes for workload CIDRs ensure east-west traffic also hits NW-FW.
resource "aws_ec2_transit_gateway_route" "spoke_workload_a" {
  destination_cidr_block         = var.workload_a_cidr
  transit_gateway_attachment_id  = local.fw_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke.id
}

resource "aws_ec2_transit_gateway_route" "spoke_workload_b" {
  destination_cidr_block         = var.workload_b_cidr
  transit_gateway_attachment_id  = local.fw_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke.id
}

# ALB VPC CIDR in spoke-rt — return traffic from workload VPCs to ALB hits NW-FW.
resource "aws_ec2_transit_gateway_route" "spoke_alb" {
  destination_cidr_block         = var.alb_vpc_cidr
  transit_gateway_attachment_id  = local.fw_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke.id
}

# ── Firewall RT Routes ────────────────────────────────────────────────────────
# After NW-FW inspects traffic, it forwards to the correct destination attachment.

# East-west: inspected traffic destined for VPC A goes directly to VPC A attachment.
resource "aws_ec2_transit_gateway_route" "fw_to_workload_a" {
  destination_cidr_block         = var.workload_a_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.workload_a.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.firewall.id
}

# East-west: inspected traffic destined for VPC B goes directly to VPC B attachment.
resource "aws_ec2_transit_gateway_route" "fw_to_workload_b" {
  destination_cidr_block         = var.workload_b_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.workload_b.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.firewall.id
}

# North-south: internet-bound traffic exits via the Egress VPC (NAT GW → IGW).
resource "aws_ec2_transit_gateway_route" "fw_to_egress" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.egress.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.firewall.id
}

# ALB VPC: after inspection, forward traffic destined for ALB VPC to ALB attachment.
resource "aws_ec2_transit_gateway_route" "fw_to_alb" {
  destination_cidr_block         = var.alb_vpc_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.alb.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.firewall.id
}

# ── Egress RT Routes ──────────────────────────────────────────────────────────
# Return traffic from the Egress VPC must re-enter NW-FW before reaching workloads.

resource "aws_ec2_transit_gateway_route" "egress_workload_a" {
  destination_cidr_block         = var.workload_a_cidr
  transit_gateway_attachment_id  = local.fw_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.egress.id
}

resource "aws_ec2_transit_gateway_route" "egress_workload_b" {
  destination_cidr_block         = var.workload_b_cidr
  transit_gateway_attachment_id  = local.fw_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.egress.id
}

# Default route in egress RT — internet-bound traffic from the egress VPC itself
# stays within the egress VPC attachment (hairpin back to NAT GW / IGW).
resource "aws_ec2_transit_gateway_route" "egress_default" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.egress.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.egress.id
}
