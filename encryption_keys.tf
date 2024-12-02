resource "aws_kms_key" "ec2_key" {
  description = "KMS key for EC2 encryption"
  tags = {
    enable_key_rotation = true
    period              = 90
  }
}


resource "aws_kms_alias" "ec2_key_alias" {
  name          = "alias/ec2_key_alias"
  target_key_id = aws_kms_key.ec2_key.id

}

resource "aws_kms_key" "rds_key" {
  description = "KMS key for RDS encryption"
  tags = {
    enable_key_rotation = true
    period              = 90
  }

  policy = jsonencode({
    Version = "2012-10-17",
    Id      = "key-default-1",
    Statement = [
      {
        Sid    = "Enable IAM User Permissions",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${var.account_id}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      },
      {
        Sid    = "Allow RDS to use the key",
        Effect = "Allow",
        Principal = {
          Service = "rds.amazonaws.com"
        },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKeyWithoutPlaintext",
          "kms:DescribeKey"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "rds_key_alias" {
  name          = "alias/rds_key_alias"
  target_key_id = aws_kms_key.rds_key.id
}

resource "aws_kms_key" "s3_key" {
  description = "KMS key for S3 encryption"
  tags = {
    enable_key_rotation = true
    period              = 90
  }
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "EnableIAMUserPermissions",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "arn:aws:iam::${var.account_id}:root"
        },
        "Action" : "kms:*",
        "Resource" : "*"
      },
      {
        "Sid" : "AllowS3AccessToKMSKey",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "*"
        },
        "Action" : [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ],
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_kms_alias" "s3_key_alias" {
  name          = "alias/s3_key_alias"
  target_key_id = aws_kms_key.s3_key.id
}


resource "aws_kms_key" "secrets_manager_key" {
  description = "KMS key for Secrets Manager encryption"
  tags = {
    enable_key_rotation = true
    period              = 90
  }
}
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "_%@/#^&*()-+=<>?{}[]'|~$!.,;:"
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name       = "db-credentials"
  kms_key_id = aws_kms_key.secrets_manager_key.id
}
resource "aws_kms_alias" "secrets_manager_key_alias" {
  name          = "alias/secrets_manager_key_alias"
  target_key_id = aws_kms_key.secrets_manager_key.id
}
resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = "csye6225"
    password = random_password.db_password.result
    api_key  = var.sendgrid_api_key
  })
}

data "aws_secretsmanager_secret_version" "db_credentials_version_data" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
}

locals {
  db_credentials = jsondecode(data.aws_secretsmanager_secret_version.db_credentials_version_data.secret_string)
}

data "aws_acm_certificate" "ssl_certificate" {
  domain      = var.domain_name
  most_recent = true
  statuses    = ["ISSUED"]
}

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.web_app_lb.arn
  port              = 443
  protocol          = "HTTPS"

  ssl_policy      = "ELBSecurityPolicy-2016-08"
  certificate_arn = data.aws_acm_certificate.ssl_certificate.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_app_tg.arn
  }
}