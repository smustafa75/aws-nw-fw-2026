# Firewall policy ARN — passed to the tgw module when creating the NW-FW resource.
output "firewall_policy_arn" { value = aws_networkfirewall_firewall_policy.policy.arn }
