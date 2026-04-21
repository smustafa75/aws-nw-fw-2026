output "vpc_id" { value = aws_vpc.this.id }
output "tgw_subnet_ids" { value = aws_subnet.tgw[*].id }
output "nat_gateway_ids" { value = aws_nat_gateway.nat[*].id }
output "public_subnet_ids" { value = aws_subnet.public[*].id }
output "tgw_route_table_ids" { value = aws_route_table.tgw[*].id }
