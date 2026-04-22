# Instance IDs — useful for targeting SSM Run Command or referencing in other resources.
output "instance_ids" { value = aws_instance.workload[*].id }

# Private IPs — use these to test east-west connectivity (ping from VPC A to VPC B).
output "private_ips" { value = aws_instance.workload[*].private_ip }
