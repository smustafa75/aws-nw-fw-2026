locals {
  fw_name = "fw-${var.project_name}"
  azs     = ["eu-west-1a", "eu-west-1b"]
}

resource "aws_cloudwatch_dashboard" "nwfw" {
  dashboard_name = "${var.project_name}-nwfw-dashboard"

  depends_on = [
    aws_networkfirewall_firewall_policy.policy,
    aws_networkfirewall_rule_group.stateless_fwd,
    aws_networkfirewall_rule_group.stateful_allow,
  ]

  dashboard_body = jsonencode({
    widgets = [

      # ── Row 1: Received vs Passed vs Dropped (AZ-a) ──────────────────────
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

      # ── Row 1: Received vs Passed vs Dropped (AZ-b) ──────────────────────
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

      # ── Row 1: Healthy / Unhealthy endpoints ─────────────────────────────
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

      # ── Row 2: Dropped packets — both AZs on one graph ───────────────────
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

      # ── Row 2: Blocked + Rejected flows ──────────────────────────────────
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

      # ── Row 3: Stream exception policy packets ────────────────────────────
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

      # ── Row 3: No-rule-group-match packets ───────────────────────────────
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
