aws_region   = "eu-west-1"
aws_profile  = "default"
project_name = "nw-fw-tgw"

# Workload VPC A — eu-west-2a / eu-west-2b
workload_a_vpc_cidr         = "10.1.0.0/16"
workload_a_subnet_cidrs     = ["10.1.1.0/24", "10.1.2.0/24"]
workload_a_tgw_subnet_cidrs = ["10.1.10.0/28", "10.1.11.0/28"]

# Workload VPC B — eu-west-2a / eu-west-2b
workload_b_vpc_cidr         = "10.2.0.0/16"
workload_b_subnet_cidrs     = ["10.2.1.0/24", "10.2.2.0/24"]
workload_b_tgw_subnet_cidrs = ["10.2.10.0/28", "10.2.11.0/28"]

# Egress VPC
egress_vpc_cidr            = "10.0.0.0/16"
egress_public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
egress_tgw_subnet_cidrs    = ["10.0.10.0/28", "10.0.11.0/28"]

# Compute — Amazon Linux 2023 eu-west-1
ami           = "ami-0720a3ca2735bf2fa"
instance_type = "t3.micro"
disk_size     = 20

# IAM
role_name   = "fw-iam-role"
policy_name = "fw-role-policy"
s3_policy   = "fw-s3-policy"

# ALB VPC — dedicated VPC for internet-facing ALB
alb_vpc_cidr            = "10.3.0.0/16"
alb_public_subnet_cidrs = ["10.3.1.0/27", "10.3.2.0/27"]
alb_tgw_subnet_cidrs    = ["10.3.10.0/28", "10.3.11.0/28"]
