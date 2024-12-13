resource "aws_launch_template" "web_app_launch_template" {
  name          = "csye6225_launch_template"
  image_id      = var.ami_id
  instance_type = "t2.small"
  key_name      = var.key_name

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.temp_sg.id]
  }

  user_data = base64encode(<<-EOF
#!/bin/bash

# Update the package index
sudo apt update

sudo apt install -y snapd
# Install AWS CLI
sudo snap install aws-cli --classic

# Export database credentials and S3 bucket name as environment variables
echo "DATABASE_HOSTNAME=jdbc:mysql://${aws_db_instance.my_rds_instance.address}:3306/${aws_db_instance.my_rds_instance.username}?createDatabaseIfNotExist=true" | sudo tee -a /opt/webapp/app/.env > /dev/null
#echo "DATABASE_USERNAME=${aws_db_instance.my_rds_instance.username}" | sudo tee -a /opt/webapp/app/.env > /dev/null
#echo "DATABASE_PASSWORD=${aws_db_instance.my_rds_instance.password}" | sudo tee -a /opt/webapp/app/.env > /dev/null
echo "DB_PORT=5432" | sudo tee -a /opt/webapp/app/.env > /dev/null
echo "DB_HOST=${aws_db_instance.my_rds_instance.address}" | sudo tee -a /opt/webapp/app/.env > /dev/null
echo "S3_BUCKET_NAME=${aws_s3_bucket.my_bucket.bucket}" | sudo tee -a /opt/webapp/app/.env > /dev/null
echo "SNS_TOPIC_ARN=${aws_sns_topic.user_verification_topic.arn}" | sudo tee -a /opt/webapp/app/.env > /dev/null
SECRET=$(aws secretsmanager get-secret-value --secret-id db-credentials --query SecretString --output text)
DB_USERNAME=$(echo $SECRET | jq -r '.username')
DB_PASSWORD=$(echo $SECRET | jq -r '.password')
echo "DATABASE_USERNAME=$DB_USERNAME" | sudo tee -a /opt/webapp/app/.env > /dev/null
echo "DATABASE_PASSWORD=$DB_PASSWORD" | sudo tee -a /opt/webapp/app/.env > /dev/null

# echo 'export SNS_TOPIC_ARN="${aws_sns_topic.user_verification_topic.arn}"' >> /etc/environment

# Restart application service after setting environment variables
sudo systemctl daemon-reload
sudo systemctl restart webapp.service

# Start CloudWatch agent for monitoring logs and metrics 
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
-a fetch-config \
-m ec2 \
-c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
-s

EOF
  )

  iam_instance_profile {
    name = aws_iam_instance_profile.cloudwatch_instance_profile.name
  }

  # block_device_mappings {
  #   device_name = "/dev/sda1"

  #   ebs {
  #     volume_size           = 30
  #     volume_type           = "gp2"
  #     kms_key_id            = aws_kms_key.ec2_key.arn
  #     delete_on_termination = true
  #     encrypted             = true
  #   }
  # }
}


# # Auto Scaling Policies

# resource "aws_autoscaling_policy" "scale_up" {
#   name                   = "scale_up_policy"
#   autoscaling_group_name = aws_autoscaling_group.web_app_asg.name
#   policy_type            = "TargetTrackingScaling"

#   target_tracking_configuration {
#     predefined_metric_specification {
#       predefined_metric_type = "ASGAverageCPUUtilization"
#     }
#     target_value = 5.0
#   }
# }

# resource "aws_autoscaling_policy" "scale_down" {
#   name                   = "scale_down_policy"
#   autoscaling_group_name = aws_autoscaling_group.web_app_asg.name
#   policy_type            = "TargetTrackingScaling"

#   target_tracking_configuration {
#     predefined_metric_specification {
#       predefined_metric_type = "ASGAverageCPUUtilization"
#     }
#     target_value = 3.0
#   }
# }

# resource "aws_autoscaling_group" "web_app_asg" {
#   desired_capacity    = 3
#   max_size            = 5
#   min_size            = 3
#   vpc_zone_identifier = [aws_subnet.public[0].id]

#   launch_template {
#     id      = aws_launch_template.web_app_launch_template.id
#     version = "$Latest"
#   }

#   target_group_arns = [aws_lb_target_group.web_app_tg.arn]

#   tag {
#     key                 = "Name"
#     value               = "WebAppInstance"
#     propagate_at_launch = true
#   }

#   health_check_type         = "EC2"
#   health_check_grace_period = 300

#   lifecycle {
#     create_before_destroy = true
#   }
# }

resource "aws_security_group" "temp_sg" {
  vpc_id = aws_vpc.csye6225_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 8081
    to_port         = 8081
    protocol        = "tcp"
    security_groups = [aws_security_group.load_balancer_sg.id]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "application security group"
  }

  depends_on = [aws_vpc.csye6225_vpc]
}

resource "aws_autoscaling_group" "web_app_asg" {
  name = "WebAppAutoScaleGroup"
  launch_template {
    id      = aws_launch_template.web_app_launch_template.id
    version = "$Latest"
  }

  min_size            = 3
  max_size            = 5
  desired_capacity    = 3
  vpc_zone_identifier = aws_subnet.public[*].id
  target_group_arns   = [aws_lb_target_group.web_app_tg.arn]


  tag {
    key                 = "Name"
    value               = "AutoScaleWebAppInstance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = "Production"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "scale_up" {
  name                   = "scale_up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.web_app_asg.name
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "scale_down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.web_app_asg.name
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "ASG_CPUHighAlarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 5
  alarm_description   = "Alarm when average CPU utilization exceeds 5%"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_app_asg.name
  }

  alarm_actions = [
    aws_autoscaling_policy.scale_up.arn
  ]
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "ASG_CPULowAlarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 3
  alarm_description   = "Alarm when average CPU utilization drops below 3%"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_app_asg.name
  }

  alarm_actions = [
    aws_autoscaling_policy.scale_down.arn
  ]
}
