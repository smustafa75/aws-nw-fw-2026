output "tgw_id" {
  value = module.tgw.tgw_id
}

output "firewall_arn" {
  value = module.tgw.firewall_arn
}

output "workload_a_vpc_id" {
  value = module.workload_vpc_a.vpc_id
}

output "workload_b_vpc_id" {
  value = module.workload_vpc_b.vpc_id
}

output "egress_vpc_id" {
  value = module.egress_vpc.vpc_id
}

output "workload_a_instance_ids" {
  value = module.compute_a.instance_ids
}

output "workload_a_private_ips" {
  value = module.compute_a.private_ips
}

output "workload_b_instance_ids" {
  value = module.compute_b.instance_ids
}

output "workload_b_private_ips" {
  value = module.compute_b.private_ips
}
