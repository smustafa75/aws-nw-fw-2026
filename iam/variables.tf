# Name of the IAM role attached to EC2 instances.
variable "policy_name" {}

# Name of the IAM role for EC2 instances.
variable "role_name" {}

# Name of the inline S3 access policy.
variable "s3_policy" {}

# Current AWS region — used to scope SSM S3 bucket ARNs.
variable "region_info" {}

# AWS account ID — available for future policy scoping if needed.
variable "account_id" {}

# AWS partition (aws / aws-cn / aws-us-gov) — used in ARN construction.
variable "partition_info" {}
