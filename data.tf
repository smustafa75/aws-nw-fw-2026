# Current region — passed to workload_vpc (SSM endpoint service names) and firewall (dashboard).
data "aws_region" "current" {}

# Caller identity — account ID used to build IAM policy ARNs.
data "aws_caller_identity" "current" {}

# Partition — distinguishes aws / aws-cn / aws-us-gov in ARN construction.
data "aws_partition" "current" {}
