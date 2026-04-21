output "tgw_id" {
  value = aws_ec2_transit_gateway.tgw.id
}

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

output "firewall_arn" {
  value = aws_networkfirewall_firewall.fw.arn
}
