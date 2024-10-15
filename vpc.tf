resource "aws_vpc" "csye6225_vpc" {
  cidr_block = var.vpc_cidrrr

  tags = {
    Name = "dev-vpc"
  }
}
