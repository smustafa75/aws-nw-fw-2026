variable "vpc_cidr" {}
variable "public_subnet_cidrs" { type = list(string) }
variable "tgw_subnet_cidrs" { type = list(string) }
