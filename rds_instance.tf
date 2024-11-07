resource "aws_db_subnet_group" "my_db_subnet_group" {
  name        = "my-db-subnet-group"
  description = "Subnet group for RDS instances"

  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "My DB Subnet Group"
  }
}

resource "aws_db_instance" "my_rds_instance" {
  identifier             = "csye6225"
  storage_type           = "gp2"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_subnet_group_name   = aws_db_subnet_group.my_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_security_group.id]
  publicly_accessible    = false
  multi_az               = false
  username               = "csye6225"
  password               = "Cloud6225"
  port                   = 3306
  parameter_group_name   = aws_db_parameter_group.mysql_param_group.name
  skip_final_snapshot    = true

  tags = {
    Name = "csye6225"
  }

  depends_on = [aws_db_parameter_group.mysql_param_group]
}


resource "aws_security_group" "db_security_group" {
  name        = "db_security_group"
  description = "Security group for RDS instances"

  # Ingress rule to allow traffic from the application security group
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
    security_groups = [aws_security_group.temp_sg.id]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    security_groups = [aws_security_group.temp_sg.id]
  }

  vpc_id = aws_vpc.csye6225_vpc.id
}
