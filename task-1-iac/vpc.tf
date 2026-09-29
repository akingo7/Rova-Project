resource "aws_vpc" "main" {
    cidr_block           = var.vpc_cidr
    enable_dns_support   = var.enable_dns_support
    enable_dns_hostnames = var.enable_dns_hostnames
    tags                 = var.tags
}

resource "aws_internet_gateway" "main" {
    vpc_id = aws_vpc.main.id
    tags   = var.tags
}

resource "aws_subnet" "public_subnet" {
    count = var.public_subnet_count
    vpc_id                  = aws_vpc.main.id
    cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
    map_public_ip_on_launch = var.public_subnet_map_public_ip_on_launch
    availability_zone       = data.aws_availability_zones.available.names[count.index]
    tags                    = var.tags
}

resource "aws_subnet" "private_subnet" {
    count = var.private_subnet_count
    vpc_id                  = aws_vpc.main.id
    cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + var.public_subnet_count)
    map_public_ip_on_launch = var.private_subnet_map_public_ip_on_launch
    availability_zone       = data.aws_availability_zones.available.names[count.index]
    tags                    = var.tags
}

resource "aws_route_table" "public_route_table" {
    vpc_id = aws_vpc.main.id
    tags   = var.tags
}

resource "aws_route" "public_route" {
    route_table_id = aws_route_table.public_route_table.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public_route_table_association" {
    count = var.public_subnet_count
    subnet_id = aws_subnet.public_subnet[count.index].id
    route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table" "private_route_table" {
    vpc_id = aws_vpc.main.id
    tags   = var.tags
}

resource "aws_route" "private_nat_route" {
    route_table_id         = aws_route_table.private_route_table.id
    destination_cidr_block = "0.0.0.0/0"
    nat_gateway_id         = aws_nat_gateway.nat_gateway.id
}

resource "aws_route_table_association" "private_route_table_association" {
    count = var.private_subnet_count
    subnet_id = aws_subnet.private_subnet[count.index].id
    route_table_id = aws_route_table.private_route_table.id
}

resource "aws_eip" "nat" {
    domain = "vpc"
}

resource "aws_nat_gateway" "nat_gateway" {
    subnet_id = aws_subnet.public_subnet[0].id
    allocation_id = aws_eip.nat.id
    tags = var.tags
}