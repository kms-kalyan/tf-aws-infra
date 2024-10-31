# Generate a random UUID for the bucket name
resource "random_uuid" "bucket_name" {}

# Define your S3 bucket without the deprecated 'acl' argument
resource "aws_s3_bucket" "my_bucket" {
  bucket        = random_uuid.bucket_name.result
  force_destroy = true

  tags = {
    Name        = "My S3 Bucket"
    Environment = "Dev"
  }
}

# Use aws_s3_bucket_acl to set the ACL for the bucket
resource "aws_s3_bucket_acl" "my_bucket_acl" {
  bucket = aws_s3_bucket.my_bucket.id
  acl    = "private"
}

# Server-side encryption configuration for the S3 bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "my_bucket_sse" {
  bucket = aws_s3_bucket.my_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lifecycle configuration for transitioning objects to STANDARD_IA storage class after 30 days
resource "aws_s3_bucket_lifecycle_configuration" "my_bucket_lifecycle" {
  bucket = aws_s3_bucket.my_bucket.id

  rule {
    id     = "TransitionToStandardIA"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}

# IAM Role for CloudWatch Agent
resource "aws_iam_role" "cloudwatch_agent_role" {
  name = "CloudWatchAgentServerRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach CloudWatchAgentServerPolicy to the IAM role
resource "aws_iam_role_policy_attachment" "cloudwatch_agent_policy" {
  role       = aws_iam_role.cloudwatch_agent_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Optionally, attach AmazonSSMManagedInstanceCore for Systems Manager
resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.cloudwatch_agent_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Create a custom IAM policy for S3 and IAM operations
resource "aws_iam_policy" "s3_and_iam_permissions_policy" {
  name        = "S3AndIAMPermissionsPolicy"
  description = "Policy to allow S3 ACL, Encryption, and IAM role creation"

  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      # Permissions for S3 Bucket ACL and Encryption Configuration
      {
        Effect : "Allow",
        Action : [
          "s3:GetBucketAcl",
          "s3:PutBucketAcl",
          "s3:GetEncryptionConfiguration",
          "s3:PutEncryptionConfiguration"
        ],
        Resource : [
          "*"
        ]
      },
      # Permissions for IAM Role Creation and Policy Attachment
      {
        Effect : "Allow",
        Action : [
          "iam:CreateRole",
          "iam:GetRole",
          "iam:AttachRolePolicy",
          "iam:PassRole",
          "iam:CreatePolicy"
        ],
        Resource : "*"
      }
    ]
  })
}

# Attach this policy to your user (replace with your actual username)
resource "aws_iam_user_policy_attachment" "attach_user_policy" {
  user       = "dev" # Replace with actual username
  policy_arn = aws_iam_policy.s3_and_iam_permissions_policy.arn
}