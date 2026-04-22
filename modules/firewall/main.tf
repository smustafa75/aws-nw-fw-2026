# ── Stateless Rule Group ──────────────────────────────────────────────────────
# Matches all traffic (0.0.0.0/0 → 0.0.0.0/0) and forwards it to the stateful
# engine. This is the standard pattern when stateful rules do the real work.
resource "aws_networkfirewall_rule_group" "stateless_fwd" {
  name        = "${var.project_name}-stateless-fwd"
  capacity    = 100
  type        = "STATELESS"
  description = "Forward all traffic to stateful engine"

  rule_group {
    rules_source {
      stateless_rules_and_custom_actions {
        stateless_rule {
          priority = 1
          rule_definition {
            match_attributes {
              source      { address_definition = "0.0.0.0/0" }
              destination { address_definition = "0.0.0.0/0" }
            }
            actions = ["aws:forward_to_sfe"]
          }
        }
      }
    }
  }
  tags = { Name = "${var.project_name}-stateless-fwd" }
}

# ── Stateful Rule Group ───────────────────────────────────────────────────────
# Three PASS rules:
#   sid 1 — ICMP any direction (east-west ping tests)
#   sid 2 — TCP 443 from 10.0.0.0/8 (HTTPS outbound from all workloads)
#   sid 3 — TCP 80  from 10.0.0.0/8 (HTTP outbound — remove if not needed)
# All other traffic is implicitly dropped by the default policy action.
resource "aws_networkfirewall_rule_group" "stateful_allow" {
  name        = "${var.project_name}-stateful-allow"
  capacity    = 100
  type        = "STATEFUL"
  description = "Allow ICMP and HTTPS outbound"

  rule_group {
    rules_source {
      # sid:1 — allow ICMP in any direction for east-west reachability testing.
      stateful_rule {
        action = "PASS"
        header {
          protocol         = "ICMP"
          source           = "ANY"
          source_port      = "ANY"
          destination      = "ANY"
          destination_port = "ANY"
          direction        = "ANY"
        }
        rule_option {
          keyword  = "sid"
          settings = ["1"]
        }
      }
      # sid:2 — allow HTTPS (443) from any RFC-1918 address.
      stateful_rule {
        action = "PASS"
        header {
          protocol         = "TCP"
          source           = "10.0.0.0/8"
          source_port      = "ANY"
          destination      = "ANY"
          destination_port = "443"
          direction        = "FORWARD"
        }
        rule_option {
          keyword  = "sid"
          settings = ["2"]
        }
      }
      # sid:3 — allow HTTP (80) from any RFC-1918 address.
      stateful_rule {
        action = "PASS"
        header {
          protocol         = "TCP"
          source           = "10.0.0.0/8"
          source_port      = "ANY"
          destination      = "ANY"
          destination_port = "80"
          direction        = "FORWARD"
        }
        rule_option {
          keyword  = "sid"
          settings = ["3"]
        }
      }
    }
  }
  tags = { Name = "${var.project_name}-stateful-allow" }
}

# ── Firewall Policy ───────────────────────────────────────────────────────────
# Default stateless action: forward everything to the stateful engine.
# Stateful engine evaluates the allow rules above; unmatched traffic is dropped.
resource "aws_networkfirewall_firewall_policy" "policy" {
  name = "${var.project_name}-fw-policy"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]

    stateless_rule_group_reference {
      priority     = 1
      resource_arn = aws_networkfirewall_rule_group.stateless_fwd.arn
    }
    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.stateful_allow.arn
    }
  }
  tags = { Name = "${var.project_name}-fw-policy" }
}
