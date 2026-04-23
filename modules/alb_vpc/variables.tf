variable "vpc_cidr" {}

# /27 minimum per AWS ALB subnet requirements (at least 8 free IPs per subnet).
variable "public_subnet_cidrs" { type = list(string) }

# /28 TGW attachment subnets — keep small, only TGW ENIs land here.
variable "tgw_subnet_cidrs" { type = list(string) }
