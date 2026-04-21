variable "aws_region" { default = "eu-west-1" }
variable "aws_profile" { default = "render" }
variable "project_name" { default = "nw-fw-tgw" }

# Workload VPC A
variable "workload_a_vpc_cidr" {}
variable "workload_a_subnet_cidrs" { type = list(string) }
variable "workload_a_tgw_subnet_cidrs" { type = list(string) }

# Workload VPC B
variable "workload_b_vpc_cidr" {}
variable "workload_b_subnet_cidrs" { type = list(string) }
variable "workload_b_tgw_subnet_cidrs" { type = list(string) }

# Egress VPC
variable "egress_vpc_cidr" {}
variable "egress_public_subnet_cidrs" { type = list(string) }
variable "egress_tgw_subnet_cidrs" { type = list(string) }

# Compute
variable "ami" {}
variable "instance_type" { default = "t3.micro" }
variable "disk_size" { default = 20 }

# IAM
variable "role_name" {}
variable "policy_name" {}
variable "s3_policy" {}
