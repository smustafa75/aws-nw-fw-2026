output "vpc_id" { value = aws_vpc.this.id }
output "vpc_cidr" { value = aws_vpc.this.cidr_block }
output "workload_subnet_ids" { value = aws_subnet.workload[*].id }
output "tgw_subnet_ids" { value = aws_subnet.tgw[*].id }
output "workload_sg_id" { value = aws_security_group.workload.id }
output "workload_route_table_id" { value = aws_route_table.workload.id }
