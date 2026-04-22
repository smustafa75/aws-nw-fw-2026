# ── EC2 IAM Role ──────────────────────────────────────────────────────────────
# Trust policy allows EC2 service to assume this role.
resource "aws_iam_role" "fw-ec2-role" {
  name = var.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# ── Managed Policy Attachments ────────────────────────────────────────────────
# AmazonSSMAutomationRole — allows SSM Automation documents to run on the instance.
resource "aws_iam_role_policy_attachment" "attach_pol_01" {
  role       = aws_iam_role.fw-ec2-role.name
  policy_arn = "arn:${var.partition_info}:iam::aws:policy/service-role/AmazonSSMAutomationRole"
}

# AmazonSSMManagedInstanceCore — core SSM agent permissions (Session Manager, Run Command, Patch Manager).
resource "aws_iam_role_policy_attachment" "attach_pol_02" {
  role       = aws_iam_role.fw-ec2-role.name
  policy_arn = "arn:${var.partition_info}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Custom SSM session S3 policy — grants GetObject on regional SSM S3 buckets
# so the SSM agent can download packages and documents without internet access.
resource "aws_iam_role_policy_attachment" "attach_pol_03" {
  role       = aws_iam_role.fw-ec2-role.name
  policy_arn = aws_iam_policy.ssm-session-s3.arn
}

# ── Custom Policies ───────────────────────────────────────────────────────────
# CloudWatch policy — allows instances to publish metrics and logs (policycw.json).
resource "aws_iam_policy" "policy" {
  name        = var.policy_name
  description = "Access CW"
  policy      = file("./iam/policycw.json")
}

# S3 policy — allows instances to read/write S3 (policys3.json).
resource "aws_iam_policy" "s3_policy" {
  name        = var.s3_policy
  description = "Access S3"
  policy      = file("./iam/policys3.json")
}

resource "aws_iam_policy_attachment" "policy_to_role" {
  name       = "Cloudwatch access"
  roles      = [aws_iam_role.fw-ec2-role.name]
  policy_arn = aws_iam_policy.policy.arn
}

resource "aws_iam_policy_attachment" "s3_policy_to_role" {
  name       = "S3 access"
  roles      = [aws_iam_role.fw-ec2-role.name]
  policy_arn = aws_iam_policy.s3_policy.arn
}

# ── Instance Profile ──────────────────────────────────────────────────────────
# Wraps the IAM role so it can be attached to EC2 instances.
resource "aws_iam_instance_profile" "iam_profile" {
  name = "iam_instance_profile"
  role = aws_iam_role.fw-ec2-role.name
}

# ── SSM Session Manager S3 Policy ────────────────────────────────────────────
# Grants GetObject on all regional SSM-managed S3 buckets so the SSM agent
# can operate without a NAT Gateway or internet route (VPC endpoints handle traffic).
# Also grants broad S3 read/write for session logging if an S3 bucket is configured.
resource "aws_iam_policy" "ssm-session-s3" {
  name        = "session-manager-s3"
  path        = "/"
  description = "Grant EC2 instance to communicate with SSM and S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "s3:GetObject"
        Resource = [
          "arn:${var.partition_info}:s3:::aws-ssm-${var.region_info}/*",
          "arn:${var.partition_info}:s3:::aws-windows-downloads-${var.region_info}/*",
          "arn:${var.partition_info}:s3:::amazon-ssm-${var.region_info}/*",
          "arn:${var.partition_info}:s3:::amazon-ssm-packages-${var.region_info}/*",
          "arn:${var.partition_info}:s3:::${var.region_info}-birdwatcher-prod/*",
          "arn:${var.partition_info}:s3:::aws-ssm-distributor-file-${var.region_info}/*",
          "arn:${var.partition_info}:s3:::aws-ssm-document-attachments-${var.region_info}/*",
          "arn:${var.partition_info}:s3:::patch-baseline-snapshot-${var.region_info}/*",
          "arn:${var.partition_info}:imagebuilder:${var.region_info}:*:component/*",
          "arn:${var.partition_info}:imagebuilder:${var.region_info}:*:component/"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:GetEncryptionConfiguration",
          "s3:GetBucketLocation"
        ]
        Resource = "*"
      }
    ]
  })
}
