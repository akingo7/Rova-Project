### Data Sources ###

data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["amazon"]
}

data "aws_availability_zones" "available" {
  state = "available"
}

### Backend variables ###

variable "bucket_name_backend" {
  description = "Name of the S3 bucket for backend"
  type        = string
  default     = "rova-project-bucket"
}

variable "key_backend" {
  description = "Key for the S3 backend"
  type        = string
  default     = "task-1-iac/terraform.tfstate"
}

variable "tags" {
  description = "Global tags to assign to all resources"
  type        = map(string)
}

variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_count" {
  type    = number
  default = 2
}

variable "private_subnet_count" {
  type    = number
  default = 2
}

variable "public_subnet_map_public_ip_on_launch" {
  type    = bool
  default = true
}

variable "private_subnet_map_public_ip_on_launch" {
  type    = bool
  default = false
}

variable "enable_dns_support" {
  type    = bool
  default = true
}

variable "enable_dns_hostnames" {
  type    = bool
  default = true
}
