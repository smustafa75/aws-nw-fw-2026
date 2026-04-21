variable "name" {}
variable "ami" {}
variable "instance_type" { default = "t3.micro" }
variable "disk_size" { default = 20 }
variable "subnet_ids" { type = list(string) }
variable "security_group_id" {}
variable "instance_profile" {}
