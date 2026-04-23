variable "name" { default = "alb-workload-a" }

# ALB VPC ID — both the ALB and target group must be in the same VPC.
variable "alb_vpc_id" {}

# Public subnet IDs from alb_vpc module — ALB nodes placed here.
variable "public_subnet_ids" { type = list(string) }

# ALB security group from alb_vpc module.
variable "alb_sg_id" {}

# Private IPs of EC2 instances in VPC A — registered as ip-type targets.
# IPs are outside the ALB VPC so availability_zone = "all" is required.
variable "target_ips" { type = list(string) }
