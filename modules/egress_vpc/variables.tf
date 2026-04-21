variable "vpc_cidr" {}
variable "public_subnet_cidrs" { type = list(string) }
variable "tgw_subnet_cidrs" { type = list(string) }
variable "tgw_id" {}
variable "workload_a_cidr" {}
variable "workload_b_cidr" {}
