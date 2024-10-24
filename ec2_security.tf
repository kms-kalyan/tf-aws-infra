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
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "application security group"
  }

  depends_on = [aws_vpc.csye6225_vpc]
}

resource "aws_instance" "temp_instance" {
  ami                         = var.ami_id
  instance_type               = "t2.small"
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.temp_sg.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 25
    volume_type           = "gp2"
    delete_on_termination = true
  }

  disable_api_termination = false

  user_data = <<-EOF
    #!/bin/bash
    echo "DATABASE_USERNAME='${aws_db_instance.my_rds_instance.username}'" >> /etc/environment
    echo "DATABASE_PASSWORD='${aws_db_instance.my_rds_instance.password}'" >> /etc/environment
    echo "DATABASE_HOSTNAME='${aws_db_instance.my_rds_instance.address}:5432/csye6225/'" >> /etc/environment
    # Add any other startup commands needed to run your application here

    systemctl daemon-reload
    systemctl enable webapp.service
    systemctl restart webapp.service

EOF

  tags = {
    Name = "temp_instance"
  }

  depends_on = [aws_internet_gateway.gw, aws_subnet.public]
}

resource "aws_security_group" "db_security_group" {
  name        = "db_security_group"
  description = "Security group for RDS instances"

  # Ingress rule to allow traffic from the application security group
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.temp_sg.id]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.temp_sg.id]
  }

  vpc_id = aws_vpc.csye6225_vpc.id
}
