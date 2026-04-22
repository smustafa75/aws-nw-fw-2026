# ── EC2 Instances ─────────────────────────────────────────────────────────────
# Two instances per workload VPC — one per AZ for HA testing.
# No SSH key pair — access is via SSM Session Manager using the attached IAM profile.
# Root volume is gp3, encrypted, and deleted on termination.
resource "aws_instance" "workload" {
  count                  = 2
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = var.subnet_ids[count.index]
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile   = var.instance_profile

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.disk_size
    encrypted             = true
    delete_on_termination = true
  }

  tags = { Name = "${var.name}-instance-${count.index + 1}" }
}
