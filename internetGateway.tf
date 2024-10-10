resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.csye6225_vpc.id

  tags = {
    Name = "CSYE6225-VPC-InternetGateWay"
  }
}