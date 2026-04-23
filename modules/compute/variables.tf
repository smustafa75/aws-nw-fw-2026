# Logical name prefix (e.g. "workload-a") — used in instance Name tags.
variable "name" {}

# Amazon Linux 2023 AMI ID — region-specific, set in terraform.tfvars.
variable "ami" {}

variable "instance_type" { default = "t3.micro" }

# Root EBS volume size in GB.
variable "disk_size" { default = 20 }

# Two subnet IDs (one per AZ) — instances are placed one per subnet.
variable "subnet_ids" { type = list(string) }

# Security group ID from the workload_vpc module.
variable "security_group_id" {}

# IAM instance profile name from the iam module — enables SSM access.
variable "instance_profile" {}

# Optional user_data script — defaults to installing httpd and serving index.html.
# systemctl enable ensures httpd starts on every reboot.
variable "user_data" {
  default = <<-EOF
    #!/bin/bash
    yum install -y httpd
    echo "<h1>Hello from $(hostname -f)</h1>" > /var/www/html/index.html
    systemctl enable httpd
    systemctl start httpd
  EOF
}
