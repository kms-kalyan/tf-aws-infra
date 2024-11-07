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
          "s3:ListAllMyBuckets"

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

# Instance profile to attach to EC2 instance
resource "aws_iam_instance_profile" "cloudwatch_instance_profile" {
  name = "CloudWatchInstanceProfile"
  role = aws_iam_role.cloudwatch_role.name
}

# Create a hosted zone for your main domain
resource "aws_route53_zone" "main" {
  name = "madhusai.me"
}

resource "aws_route53_zone" "dev" {
  name = "dev.madhusai.me"
}

# resource "aws_route53_record" "dev" {
#   zone_id = aws_route53_zone.dev.zone_id
#   name    = "dev.madhusai.me"
#   type    = "A"
#   ttl     = "300"
#   records = [aws_instance.temp_instance.public_ip]
# }

resource "aws_route53_record" "dev" {
  zone_id = aws_route53_zone.dev.zone_id
  name    = "dev.madhusai.me"
  type    = "A"

  alias {
    name                   = aws_lb.web_app_alb.dns_name
    zone_id                = aws_lb.web_app_alb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_zone" "demo" {
  name = "demo.madhusai.me"
}

resource "aws_route53_record" "demo" {
  zone_id = aws_route53_zone.demo.zone_id
  name    = "demo.madhusai.me"
  type    = "A"

  alias {
    name                   = aws_lb.web_app_alb.dns_name
    zone_id                = aws_lb.web_app_alb.zone_id
    evaluate_target_health = true
  }
}