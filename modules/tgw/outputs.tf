# TGW ID — consumed by root main.tf to add VPC-side routes after TGW is ready.
output "tgw_id" {
  value = aws_ec2_transit_gateway.tgw.id
}

# NW-FW TGW attachment ID — used internally for route table associations and routes.
output "fw_attachment_id" {
  value = local.fw_attachment_id
}

output "workload_a_attachment_id" {
  value = aws_ec2_transit_gateway_vpc_attachment.workload_a.id
}

output "workload_b_attachment_id" {
  value = aws_ec2_transit_gateway_vpc_attachment.workload_b.id
}

output "egress_attachment_id" {
  value = aws_ec2_transit_gateway_vpc_attachment.egress.id
}

output "alb_attachment_id" {
  value = aws_ec2_transit_gateway_vpc_attachment.alb.id
}

# NW-FW ARN — surfaced to root outputs for reference.
output "firewall_arn" {
  value = aws_networkfirewall_firewall.fw.arn
}
