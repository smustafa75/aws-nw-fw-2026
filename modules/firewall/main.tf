# Stateless rule group — forward all to stateful engine
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

# Stateful rule group — allow ICMP + HTTP/S, drop rest
resource "aws_networkfirewall_rule_group" "stateful_allow" {
  name        = "${var.project_name}-stateful-allow"
  capacity    = 100
  type        = "STATEFUL"
  description = "Allow ICMP and HTTPS outbound"

  rule_group {
    rules_source {
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
        rule_option { keyword = "sid"; settings = ["1"] }
      }
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
        rule_option { keyword = "sid"; settings = ["2"] }
      }
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
        rule_option { keyword = "sid"; settings = ["3"] }
      }
    }
  }
  tags = { Name = "${var.project_name}-stateful-allow" }
}

# Firewall policy
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
