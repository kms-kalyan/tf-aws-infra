variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets"
  type        = list(string)
}


variable "availability_zones" {
  description = "List of availability zones to use"
  type        = list(string)
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "source_ami" {
  type    = string
  default = "ami-0866a3c8686eaeeba"
}

variable "key_name" {
  type    = string
  default = "ami-0866a3c8686eaeeba"
}

variable "ssh_username" {
  type    = string
  default = "ubuntu"
}

variable "ami_id" {
  type = string
}

# variable "database_host" {
#   type = string
# }
# variable "database_user" {
#   type = string
# }
variable "jar_path" {
  type = string
}
variable "sendgrid_api_key" {
  type = string
}
variable "instance_host" {
  type = string
}
