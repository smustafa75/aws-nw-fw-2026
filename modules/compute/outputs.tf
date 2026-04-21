output "instance_ids" { value = aws_instance.workload[*].id }
output "private_ips" { value = aws_instance.workload[*].private_ip }
