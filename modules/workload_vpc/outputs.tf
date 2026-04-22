output "vpc_id" { value = aws_vpc.this.id }
output "vpc_cidr" { value = aws_vpc.this.cidr_block }

# Workload subnet IDs — passed to compute module for EC2 placement.
output "workload_subnet_ids" { value = aws_subnet.workload[*].id }

# TGW subnet IDs — passed to tgw module for VPC attachment.
output "tgw_subnet_ids" { value = aws_subnet.tgw[*].id }

# Security group ID — shared by EC2 instances and SSM VPC endpoints.
output "workload_sg_id" { value = aws_security_group.workload.id }

# Route table ID — root main.tf adds the default route to TGW after TGW is created.
output "workload_route_table_id" { value = aws_route_table.workload.id }
