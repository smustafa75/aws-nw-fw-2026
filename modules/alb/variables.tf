variable "name" { default = "alb-workload-a" }

# ALB VPC ID — used for the ALB itself (subnets and security group).
variable "alb_vpc_id" {}

# Target VPC ID — the VPC where EC2 targets live (VPC A).
# For ip-type cross-VPC targets, the target group vpc_id must be the
# VPC containing the target IPs, not the VPC containing the ALB.
variable "target_vpc_id" {}

# Public subnet IDs from alb_vpc module — ALB nodes placed here.
variable "public_subnet_ids" { type = list(string) }

# ALB security group from alb_vpc module.
variable "alb_sg_id" {}

# Private IPs of EC2 instances in VPC A — registered as ip-type targets.
variable "target_ips" { type = list(string) }
