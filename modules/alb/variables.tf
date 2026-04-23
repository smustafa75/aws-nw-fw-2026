variable "name" { default = "alb-workload-a" }

# ALB VPC ID — target group must be in the same VPC as the ALB.
variable "vpc_id" {}

# Public subnet IDs from alb_vpc module — ALB nodes placed here.
variable "public_subnet_ids" { type = list(string) }

# ALB security group from alb_vpc module.
variable "alb_sg_id" {}

# Private IPs of EC2 instances in VPC A — registered as ip-type targets.
variable "target_ips" { type = list(string) }
