# Region, account, and partition used by IAM and workload_vpc modules
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
