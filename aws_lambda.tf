resource "aws_sns_topic" "user_verification_topic" {
  name = "VerifyEmail"
}


resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version : "2012-10-17",
    Statement : [{
      Action : "sts:AssumeRole",
      Effect : "Allow",
      Principal : {
        Service : "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "lambda_exec_policy" {
  name = "lambda_exec_policy"

  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Action : [
          "logs:*",
          "cloudwatch:*",
          "sns:*",
          "secretsmanager:GetSecretValue",
          "rds-db:connect"
        ],
        Effect : "Allow",
        Resource : "*"
      }
    ]
  })
}

resource "aws_sns_topic_policy" "user_verification_topic_policy" {
  arn = aws_sns_topic.user_verification_topic.arn

  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Principal : {
          AWS : aws_iam_role.lambda_exec_role.arn
        },
        Action : "sns:Publish",
        Resource : aws_sns_topic.user_verification_topic.arn
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "lambda_exec_attach_policy" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_exec_policy.arn
}

resource "aws_sns_topic_subscription" "lambda_sns_subscription" {
  topic_arn = aws_sns_topic.user_verification_topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.user_verification_lambda.arn

  # Grant permission for SNS to invoke the Lambda function
  depends_on = [aws_lambda_permission.allow_sns_invoke]
}

resource "aws_lambda_permission" "allow_sns_invoke" {
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.user_verification_lambda.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.user_verification_topic.arn
}


# resource "aws_s3_bucket" "lambda_bucket" {
#   bucket = "my-lambda-code-bucket"
#   acl    = "private"

#   tags = {
#     Name        = "LambdaCodeBucket"
#     Environment = "Development"
#   }
# }

resource "aws_s3_object" "lambda_jar" {
  bucket = aws_s3_bucket.my_bucket.id
  key    = "serverless.jar"
  source = var.jar_path
  etag   = filemd5(var.jar_path)
}

resource "aws_lambda_function" "user_verification_lambda" {
  s3_bucket        = aws_s3_bucket.my_bucket.id
  s3_key           = aws_s3_object.lambda_jar.key
  function_name    = "VerifyEmail"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "com.csye6225.verify.email.serverless.VerifyEmail::handleRequest"
  runtime          = "java17"
  source_code_hash = filebase64sha256(var.jar_path)
  timeout          = 30
  memory_size      = 512
}