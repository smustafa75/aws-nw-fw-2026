# Minimum Terraform version and provider constraints.
# AWS provider ~> 6.0 is required for the native NW-FW TGW attachment resource.
terraform {
  required_version = ">= 1.3"

  backend "s3" {
    bucket  = "res-test-01"
    key     = "nw-fw/terraform.tfstate"
    region  = "eu-west-1"
    profile = "default"
    # Add dynamodb_table = "<table-name>" here if you want state locking
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
