output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "tgw_subnet_ids" {
  value = aws_subnet.tgw[*].id
}

output "tgw_route_table_ids" {
  value = aws_route_table.tgw[*].id
}

output "alb_sg_id" {
  value = aws_security_group.alb.id
}
