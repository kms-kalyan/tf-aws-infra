# resource "aws_instance" "temp_instance" {
#   ami                         = var.ami_id
#   instance_type               = "t2.small"
#   subnet_id                   = aws_subnet.public[0].id
#   vpc_security_group_ids      = [aws_security_group.temp_sg.id]
#   associate_public_ip_address = true
#   iam_instance_profile        = aws_iam_instance_profile.cloudwatch_instance_profile.name

#   root_block_device {
#     volume_size           = 25
#     volume_type           = "gp2"
#     delete_on_termination = true
#   }

#   disable_api_termination = false

#   user_data = <<-EOF
# #!/bin/bash
# echo "DATABASE_HOSTNAME=jdbc:mysql://${aws_db_instance.my_rds_instance.address}:3306/${aws_db_instance.my_rds_instance.username}?createDatabaseIfNotExist=true" | sudo tee -a /opt/webapp/app/.env > /dev/null
# echo "DATABASE_USERNAME=${aws_db_instance.my_rds_instance.username}" | sudo tee -a /opt/webapp/app/.env > /dev/null
# echo "DATABASE_PASSWORD=${aws_db_instance.my_rds_instance.password}" | sudo tee -a /opt/webapp/app/.env > /dev/null
# echo "DB_PORT=5432" | sudo tee -a /opt/webapp/app/.env > /dev/null
# echo "DB_HOST=${aws_db_instance.my_rds_instance.address}" | sudo tee -a /opt/webapp/app/.env > /dev/null
# echo "S3_BUCKET_NAME=${aws_s3_bucket.my_bucket.bucket}" | sudo tee -a /opt/webapp/app/.env > /dev/null

# sudo systemctl daemon-reload
# sudo systemctl restart webapp.service

# sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
#   -a fetch-config \
#   -m ec2 \
#   -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
#   -s

#   EOF

#   tags = {
#     Name = "temp_instance"
#   }

#   depends_on = [aws_internet_gateway.gw, aws_subnet.public]
# }

resource "aws_launch_template" "web_app_launch_template" {
  name_prefix   = "csye6225_asg"
  image_id      = var.ami_id
  instance_type = "t2.small"
  key_name      = var.key_name

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.temp_sg.id]
  }

  user_data = base64encode(<<-EOF
#!/bin/bash
echo "DATABASE_HOSTNAME=jdbc:mysql://${aws_db_instance.my_rds_instance.address}:3306/${aws_db_instance.my_rds_instance.username}?createDatabaseIfNotExist=true" | sudo tee -a /opt/webapp/app/.env > /dev/null
echo "DATABASE_USERNAME=${aws_db_instance.my_rds_instance.username}" | sudo tee -a /opt/webapp/app/.env > /dev/null
echo "DATABASE_PASSWORD=${aws_db_instance.my_rds_instance.password}" | sudo tee -a /opt/webapp/app/.env > /dev/null
echo "DB_PORT=5432" | sudo tee -a /opt/webapp/app/.env > /dev/null
echo "DB_HOST=${aws_db_instance.my_rds_instance.address}" | sudo tee -a /opt/webapp/app/.env > /dev/null
echo "S3_BUCKET_NAME=${aws_s3_bucket.my_bucket.bucket}" | sudo tee -a /opt/webapp/app/.env > /dev/null

sudo systemctl daemon-reload
sudo systemctl restart webapp.service

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
}

resource "aws_autoscaling_policy" "scale_up" {
  name                   = "scale_up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.web_app_asg.name

  metric_aggregation_type = "Average"
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "scale_down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.web_app_asg.name

  metric_aggregation_type = "Average"
}

resource "aws_autoscaling_group" "web_app_asg" {
  desired_capacity    = 3 # Set within min and max size
  max_size            = 5
  min_size            = 3
  vpc_zone_identifier = [aws_subnet.public[0].id]

  launch_template {
    id      = aws_launch_template.web_app_launch_template.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.web_app_tg.arn]

  tag {
    key                 = "Name"
    value               = "WebAppInstance"
    propagate_at_launch = true
  }

  health_check_type         = "EC2"
  health_check_grace_period = 300

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "temp_sg" {
  vpc_id = aws_vpc.csye6225_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 8081
    to_port         = 8081
    protocol        = "tcp"
    security_groups = [aws_security_group.load_balancer_sg.id]
  }

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
