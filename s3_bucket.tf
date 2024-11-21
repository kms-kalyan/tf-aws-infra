resource "aws_s3_bucket" "my_bucket" {
  bucket        = "profile-pics-${random_uuid.bucket_uuid.result}"
  acl           = "private"
  force_destroy = true

  lifecycle_rule {
    enabled = true
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

# resource "aws_s3_bucket" "lambda_bucket" {
#   bucket = "my-lambda-code-bucket"
#   acl    = "private"

#   tags = {
#     Name        = "LambdaCodeBucket"
#     Environment = "Development"
#   }
#   #region = "us-east-1"
# }


# resource "aws_s3_object" "lambda_jar" {
#   bucket = aws_s3_bucket.lambda_bucket.id
#   key    = "my-function.jar"
#   source = var.jar_path
#   etag   = filemd5(var.jar_path)
# }

resource "random_uuid" "bucket_uuid" {}


resource "aws_cloudwatch_log_group" "csye6225" {
  name              = "csye6225"
  retention_in_days = 7
}

resource "aws_iam_role" "cloudwatch_role" {
  name = "CloudWatchAgentRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      },
    ]
  })
}

resource "aws_iam_policy" "cloudwatch_policy" {
  name        = "CloudWatchPolicy"
  description = "CloudWatch Policy - EC2"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "cloudwatch:PutMetricData",
          "logs:CreateLogGroup",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "s3:ListAllMyBuckets",
          "SNS:Publish"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_attach" {
  policy_arn = aws_iam_policy.cloudwatch_policy.arn
  role       = aws_iam_role.cloudwatch_role.name
}

resource "aws_iam_instance_profile" "cloudwatch_instance_profile" {
  name = "CloudWatchInstanceProfile"
  role = aws_iam_role.cloudwatch_role.name
}

# data "aws_route53_zone" "dev" {
#   name = "dev.madhusai.me"
# }

# resource "aws_route53_record" "dev" {
#   zone_id = data.aws_route53_zone.dev.zone_id
#   name    = "dev.madhusai.me"
#   type    = "A"

#   alias {
#     name                   = aws_lb.web_app_lb.dns_name
#     zone_id                = aws_lb.web_app_lb.zone_id
#     evaluate_target_health = true
#   }
# }

data "aws_route53_zone" "demo" {
  name = "demo.madhusai.me"
}

resource "aws_route53_record" "demo" {
  zone_id = data.aws_route53_zone.demo.zone_id
  name    = "demo.madhusai.me"
  type    = "A"

  alias {
    name                   = aws_lb.web_app_lb.dns_name
    zone_id                = aws_lb.web_app_lb.zone_id
    evaluate_target_health = true
  }
}