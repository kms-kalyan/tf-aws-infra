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
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = "db.t4g.micro"
  allocated_storage      = 20
  db_subnet_group_name   = aws_db_subnet_group.my_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_security_group.id]
  publicly_accessible    = false
  multi_az               = false
  username               = "csye6225"
  password               = "Cloud6225"
  parameter_group_name   = aws_db_parameter_group.postgresql_param_group.name
  skip_final_snapshot    = true

  tags = {
    Name = "csye6225"
  }

  depends_on = [aws_db_parameter_group.postgresql_param_group]
}

