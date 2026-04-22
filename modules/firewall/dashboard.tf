# ── CloudWatch Dashboard ──────────────────────────────────────────────────────
# Dashboard name: <project_name>-nwfw-dashboard
# All metrics are at 1-minute resolution, scoped per AZ.
# Layout: 3 rows × 24 columns (each widget is 8 or 12 wide).

locals {
  fw_name = "fw-${var.project_name}"
  # Hard-coded to eu-west-1 AZs — update if deploying to another region.
  azs = ["eu-west-1a", "eu-west-1b"]
}

resource "aws_cloudwatch_dashboard" "nwfw" {
  dashboard_name = "${var.project_name}-nwfw-dashboard"

  # Explicit depends_on ensures the dashboard is only created after the firewall
  # policy and rule groups exist (avoids metric-not-found errors on first apply).
  depends_on = [
    aws_networkfirewall_firewall_policy.policy,
    aws_networkfirewall_rule_group.stateless_fwd,
    aws_networkfirewall_rule_group.stateful_allow,
  ]

  dashboard_body = jsonencode({
    widgets = [

      # ── Row 1 (y=0): Traffic overview per AZ + endpoint health ───────────

      # Received / Passed / Dropped packets for AZ-a (stateless engine).
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 8
        height = 6
        properties = {
          region = var.region
          title  = "Traffic Overview — ${local.azs[0]}"
          view   = "timeSeries"
          stat   = "Sum"
          period = 60
          metrics = [
            ["AWS/NetworkFirewall", "ReceivedPackets", "FirewallName", local.fw_name, "AvailabilityZone", local.azs[0], "Engine", "Stateless"],
            ["AWS/NetworkFirewall", "PassedPackets", "FirewallName", local.fw_name, "AvailabilityZone", local.azs[0], "Engine", "Stateless"],
            ["AWS/NetworkFirewall", "DroppedPackets", "FirewallName", local.fw_name, "AvailabilityZone", local.azs[0], "Engine", "Stateless"]
          ]
        }
      },

      # Received / Passed / Dropped packets for AZ-b (stateless engine).
      {
        type   = "metric"
        x      = 8
        y      = 0
        width  = 8
        height = 6
        properties = {
          region = var.region
          title  = "Traffic Overview — ${local.azs[1]}"
          view   = "timeSeries"
          stat   = "Sum"
          period = 60
          metrics = [
            ["AWS/NetworkFirewall", "ReceivedPackets", "FirewallName", local.fw_name, "AvailabilityZone", local.azs[1], "Engine", "Stateless"],
            ["AWS/NetworkFirewall", "PassedPackets", "FirewallName", local.fw_name, "AvailabilityZone", local.azs[1], "Engine", "Stateless"],
            ["AWS/NetworkFirewall", "DroppedPackets", "FirewallName", local.fw_name, "AvailabilityZone", local.azs[1], "Engine", "Stateless"]
          ]
        }
      },

      # Healthy vs Unhealthy endpoints — alarm annotation at 1 to highlight degraded state.
      {
        type   = "metric"
        x      = 16
        y      = 0
        width  = 8
        height = 6
        properties = {
          region = var.region
          title  = "Endpoint Health"
          view   = "timeSeries"
          stat   = "Minimum"
          period = 60
          metrics = [
            ["AWS/NetworkFirewall", "HealthyEndpoints", "FirewallName", local.fw_name],
            ["AWS/NetworkFirewall", "UnhealthyEndpoints", "FirewallName", local.fw_name]
          ]
          annotations = {
            horizontal = [{ value = 1, label = "Min healthy", color = "#ff0000" }]
          }
        }
      },

      # ── Row 2 (y=6): Dropped packets + blocked/rejected flows ─────────────

      # Dropped packets for both AZs on a single graph — easy side-by-side comparison.
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          region = var.region
          title  = "Dropped Packets (both AZs)"
          view   = "timeSeries"
          stat   = "Sum"
          period = 60
          metrics = [
            ["AWS/NetworkFirewall", "DroppedPackets", "FirewallName", local.fw_name, "AvailabilityZone", local.azs[0], "Engine", "Stateless", { label = "Dropped ${local.azs[0]}", color = "#d62728" }],
            ["AWS/NetworkFirewall", "DroppedPackets", "FirewallName", local.fw_name, "AvailabilityZone", local.azs[1], "Engine", "Stateless", { label = "Dropped ${local.azs[1]}", color = "#ff7f0e" }]
          ]
        }
      },

      # Blocked and Rejected flows from the stateful engine — indicates policy hits.
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          region = var.region
          title  = "Blocked & Rejected Flows"
          view   = "timeSeries"
          stat   = "Sum"
          period = 60
          metrics = [
            ["AWS/NetworkFirewall", "BlockedFlows", "FirewallName", local.fw_name, "AvailabilityZone", local.azs[0], "Engine", "Stateful"],
            ["AWS/NetworkFirewall", "BlockedFlows", "FirewallName", local.fw_name, "AvailabilityZone", local.azs[1], "Engine", "Stateful"],
            ["AWS/NetworkFirewall", "RejectedFlows", "FirewallName", local.fw_name, "AvailabilityZone", local.azs[0], "Engine", "Stateful"],
            ["AWS/NetworkFirewall", "RejectedFlows", "FirewallName", local.fw_name, "AvailabilityZone", local.azs[1], "Engine", "Stateful"]
          ]
        }
      },

      # ── Row 3 (y=12): Diagnostic metrics ─────────────────────────────────

      # StreamExceptionPolicyPackets — non-zero values indicate asymmetric routing.
      # If traffic enters NW-FW on one AZ but the return path uses a different AZ,
      # the stateful engine cannot match the flow and applies the stream exception policy.
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          region = var.region
          title  = "Stream Exception Policy Packets (asymmetric routing indicator)"
          view   = "timeSeries"
          stat   = "Sum"
          period = 60
          metrics = [
            ["AWS/NetworkFirewall", "StreamExceptionPolicyPackets", "FirewallName", local.fw_name, "AvailabilityZone", local.azs[0], "Engine", "Stateful"],
            ["AWS/NetworkFirewall", "StreamExceptionPolicyPackets", "FirewallName", local.fw_name, "AvailabilityZone", local.azs[1], "Engine", "Stateful"]
          ]
        }
      },

      # NoRuleGroupMatchPackets — traffic that passed through without matching any rule group.
      # Non-zero values suggest a gap in the firewall policy (missing rule group or capacity).
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          region = var.region
          title  = "No Rule Group Match Packets (policy gap indicator)"
          view   = "timeSeries"
          stat   = "Sum"
          period = 60
          metrics = [
            ["AWS/NetworkFirewall", "NoRuleGroupMatchPackets", "FirewallName", local.fw_name, "AvailabilityZone", local.azs[0], "Engine", "Stateful"],
            ["AWS/NetworkFirewall", "NoRuleGroupMatchPackets", "FirewallName", local.fw_name, "AvailabilityZone", local.azs[1], "Engine", "Stateful"]
          ]
        }
      }
    ]
  })
}
