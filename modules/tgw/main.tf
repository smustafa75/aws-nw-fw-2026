data "aws_availability_zones" "available" { state = "available" }

resource "aws_ec2_transit_gateway" "tgw" {
  description                     = "TGW - ${var.project_name}"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  auto_accept_shared_attachments  = "enable"
  tags = { Name = "TGW-${var.project_name}" }
}

# ── TGW VPC Attachments ───────────────────────────────────────────────────────

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

# ── NW-FW Native TGW Attachment ───────────────────────────────────────────────

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

resource "aws_ec2_transit_gateway_route_table_association" "workload_a" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.workload_a.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke.id
}

resource "aws_ec2_transit_gateway_route_table_association" "workload_b" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.workload_b.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke.id
}

resource "aws_ec2_transit_gateway_route_table_association" "fw" {
  transit_gateway_attachment_id  = aws_networkfirewall_firewall.fw.firewall_status[0].transit_gateway_attachment_sync_states[0].attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.firewall.id
}

resource "aws_ec2_transit_gateway_route_table_association" "egress" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.egress.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.egress.id
}

# ── Locals ────────────────────────────────────────────────────────────────────

locals {
  fw_attachment_id = aws_networkfirewall_firewall.fw.firewall_status[0].transit_gateway_attachment_sync_states[0].attachment_id
}

# ── Spoke RT Routes → all traffic to NW-FW ───────────────────────────────────

resource "aws_ec2_transit_gateway_route" "spoke_default" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = local.fw_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke.id
}

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

# ── Firewall RT Routes → back to spokes + egress ──────────────────────────────

resource "aws_ec2_transit_gateway_route" "fw_to_workload_a" {
  destination_cidr_block         = var.workload_a_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.workload_a.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.firewall.id
}

resource "aws_ec2_transit_gateway_route" "fw_to_workload_b" {
  destination_cidr_block         = var.workload_b_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.workload_b.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.firewall.id
}

resource "aws_ec2_transit_gateway_route" "fw_to_egress" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.egress.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.firewall.id
}

# ── Egress RT Routes → return traffic via NW-FW ───────────────────────────────

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
