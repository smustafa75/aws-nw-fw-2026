# ── CPU Utilization Alarm ─────────────────────────────────────────────────────
# Triggers when CPU > 50% for 2 consecutive 5-minute periods.
# CPUUtilization is a native EC2 metric — no agent required.
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  count               = 2
  alarm_name          = "${var.name}-instance-${count.index + 1}-cpu-high"
  alarm_description   = "CPU utilization above 50% for 10 minutes"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 50
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = aws_instance.workload[count.index].id
  }

  tags = { Name = "${var.name}-cpu-alarm-${count.index + 1}" }
}

# ── Disk Utilization Alarm ────────────────────────────────────────────────────
# Triggers when root volume used_percent > 70% for 2 consecutive 5-minute periods.
# Requires the CloudWatch agent to be running (installed via user_data).
# Metric published under CWAgent namespace by the agent.
resource "aws_cloudwatch_metric_alarm" "disk_high" {
  count               = 2
  alarm_name          = "${var.name}-instance-${count.index + 1}-disk-high"
  alarm_description   = "Disk utilization above 70% on root volume"
  namespace           = "CWAgent"
  metric_name         = "disk_used_percent"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 70
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = aws_instance.workload[count.index].id
    path       = "/"
    fstype     = "xfs"
  }

  tags = { Name = "${var.name}-disk-alarm-${count.index + 1}" }
}
