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
  # $$ is the HCL escape for a literal $ — prevents Terraform from interpolating
  # $(hostname -f) at plan time; the instance shell expands it correctly at boot.
  default = <<-EOF
    #!/bin/bash
    yum install -y httpd amazon-cloudwatch-agent
    echo "<h1>Hello from $$(hostname -f)</h1>" > /var/www/html/index.html
    systemctl enable --now httpd

    # CloudWatch agent config — collect disk used_percent on root volume every 60s
    cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CWEOF'
    {
      "metrics": {
        "metrics_collected": {
          "disk": {
            "measurement": ["used_percent"],
            "resources": ["/"],
            "metrics_collection_interval": 60
          }
        }
      }
    }
    CWEOF

    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
      -a fetch-config -m ec2 \
      -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s
  EOF
}
