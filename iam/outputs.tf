# IAM role name — useful for attaching additional policies outside this module.
output "iam_role" {
  value = aws_iam_role.fw-ec2-role.name
}

# IAM role ARN — used in trust policies or cross-account scenarios.
output "iam_role_arn" {
  value = aws_iam_role.fw-ec2-role.arn
}

# Instance profile ARN — can be used in launch templates or other automation.
output "iam_instance_profile_arn" {
  value = aws_iam_instance_profile.iam_profile.arn
}

# Instance profile name — passed to compute modules to attach to EC2 instances.
output "iam_instance_profile" {
  value = aws_iam_instance_profile.iam_profile.name
}
