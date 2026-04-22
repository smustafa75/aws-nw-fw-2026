output "vpc_id" { value = aws_vpc.this.id }

# TGW subnet IDs — passed to tgw module for the egress VPC attachment.
output "tgw_subnet_ids" { value = aws_subnet.tgw[*].id }

output "nat_gateway_ids" { value = aws_nat_gateway.nat[*].id }
output "public_subnet_ids" { value = aws_subnet.public[*].id }

# Per-AZ TGW route table IDs — root main.tf adds workload CIDR return routes here.
output "tgw_route_table_ids" { value = aws_route_table.tgw[*].id }

# Public route table ID — root main.tf adds workload CIDR routes so NAT GW
# reply traffic can reach the TGW on the return path.
output "public_route_table_id" { value = aws_route_table.public.id }
