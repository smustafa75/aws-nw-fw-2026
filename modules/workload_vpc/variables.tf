variable "name" {}
variable "vpc_cidr" {}
variable "workload_subnet_cidrs" { type = list(string) }
variable "tgw_subnet_cidrs" { type = list(string) }
variable "region" {}
