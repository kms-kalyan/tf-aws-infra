resource "aws_db_parameter_group" "postgresql_param_group" {
  name        = "my-postgresql-15-group"
  family      = "postgres15" # Ensure this matches the PostgreSQL version
  description = "Custom parameter group for PostgreSQL 15"

}