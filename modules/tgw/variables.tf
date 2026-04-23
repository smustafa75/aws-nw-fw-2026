# Used as a prefix for TGW, NW-FW, and CloudWatch log group names.
variable "project_name" {}

# ARN of the NW-FW policy created by the firewall module.
variable "firewall_policy_arn" {}

# Workload VPC A — VPC ID and TGW attachment subnet IDs.
variable "workload_a_vpc_id" {}
variable "workload_a_tgw_subnet_ids" { type = list(string) }
# CIDR used to build TGW route table entries pointing back to VPC A.
variable "workload_a_cidr" {}

# Workload VPC B — same pattern as VPC A.
variable "workload_b_vpc_id" {}
variable "workload_b_tgw_subnet_ids" { type = list(string) }
variable "workload_b_cidr" {}

# Egress VPC — VPC ID and TGW attachment subnet IDs.
variable "egress_vpc_id" {}
variable "egress_tgw_subnet_ids" { type = list(string) }

# ALB VPC — VPC ID, TGW attachment subnet IDs, and CIDR for route table entries.
variable "alb_vpc_id" {}
variable "alb_tgw_subnet_ids" { type = list(string) }
variable "alb_vpc_cidr" {}

# CloudWatch log retention for NW-FW flow and alert logs (days).
variable "log_retention_days" {
  type    = number
  default = 30
}
