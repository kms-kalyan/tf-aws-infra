resource "aws_db_parameter_group" "mysql_param_group" {
  name        = "my-mysql-8-group"
  family      = "mysql8.0"
  description = "Custom parameter group for MySQL 8.0"
}