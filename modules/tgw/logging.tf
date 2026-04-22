# ── NW-FW CloudWatch Logging ──────────────────────────────────────────────────
# Two separate log groups: one for connection flow records, one for rule-match alerts.
# Retention is configurable via var.log_retention_days (default 30 days).

resource "aws_cloudwatch_log_group" "nwfw_flow" {
  name              = "/aws/network-firewall/${var.project_name}/flow"
  retention_in_days = var.log_retention_days
  tags              = { Name = "nwfw-flow-${var.project_name}" }
}

resource "aws_cloudwatch_log_group" "nwfw_alert" {
  name              = "/aws/network-firewall/${var.project_name}/alert"
  retention_in_days = var.log_retention_days
  tags              = { Name = "nwfw-alert-${var.project_name}" }
}

# Attaches both log destinations to the firewall.
# FLOW logs every accepted/dropped connection; ALERT logs rule-match events.
resource "aws_networkfirewall_logging_configuration" "fw" {
  firewall_arn = aws_networkfirewall_firewall.fw.arn

  logging_configuration {
    log_destination_config {
      log_type             = "FLOW"
      log_destination_type = "CloudWatchLogs"
      log_destination      = { logGroup = aws_cloudwatch_log_group.nwfw_flow.name }
    }
    log_destination_config {
      log_type             = "ALERT"
      log_destination_type = "CloudWatchLogs"
      log_destination      = { logGroup = aws_cloudwatch_log_group.nwfw_alert.name }
    }
  }
}
