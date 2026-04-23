# ── Networking ────────────────────────────────────────────────────────────────
output "tgw_id" {
  description = "Transit Gateway ID — use when peering or adding more attachments."
  value       = module.tgw.tgw_id
}

output "firewall_arn" {
  description = "ARN of the AWS Network Firewall (TGW-attached)."
  value       = module.tgw.firewall_arn
}

output "workload_a_vpc_id" {
  description = "VPC ID for Workload A."
  value       = module.workload_vpc_a.vpc_id
}

output "workload_b_vpc_id" {
  description = "VPC ID for Workload B."
  value       = module.workload_vpc_b.vpc_id
}

output "egress_vpc_id" {
  description = "VPC ID for the Egress VPC (NAT GW + IGW)."
  value       = module.egress_vpc.vpc_id
}

# ── Compute ───────────────────────────────────────────────────────────────────
# Use these IPs with SSM Session Manager to test east-west and north-south flows.
output "workload_a_instance_ids" {
  description = "EC2 instance IDs in Workload VPC A."
  value       = module.compute_a.instance_ids
}

output "workload_a_private_ips" {
  description = "Private IPs of Workload A instances — use for east-west ping tests."
  value       = module.compute_a.private_ips
}

output "workload_b_instance_ids" {
  description = "EC2 instance IDs in Workload VPC B."
  value       = module.compute_b.instance_ids
}

output "workload_b_private_ips" {
  description = "Private IPs of Workload B instances — use for east-west ping tests."
  value       = module.compute_b.private_ips
}

output "alb_dns_name" {
  description = "Public DNS name of the ALB — curl http://<alb_dns_name> to test end-to-end."
  value       = module.alb.alb_dns_name
}
