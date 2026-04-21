variable "project_name" {}

variable "firewall_policy_arn" {}

variable "workload_a_vpc_id" {}
variable "workload_a_tgw_subnet_ids" { type = list(string) }
variable "workload_a_cidr" {}

variable "workload_b_vpc_id" {}
variable "workload_b_tgw_subnet_ids" { type = list(string) }
variable "workload_b_cidr" {}

variable "egress_vpc_id" {}
variable "egress_tgw_subnet_ids" { type = list(string) }
