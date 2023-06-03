# Create a VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = {
    "Name" = "${var.default_tags.project}-vpc"
  }
  assign_generated_ipv6_cidr_block = true
  instance_tenancy = "default"
  enable_dns_hostnames = true
  enable_dns_support = true
}

# public subntes
resource "aws_subnet" "public" {
  count = var.public_subnet_count
  # block label
  vpc_id = aws_vpc.main.id 
  # set a range of subnet 
  # 10.255.0.0/20 -> 10.255.0.0/24
  cidr_block      = cidrsubnet(aws_vpc.main.cidr_block, 4, count.index) 
  # set a range of subnet in ipv6 format
  ipv6_cidr_block = cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, count.index)
  map_public_ip_on_launch         = true
  assign_ipv6_address_on_creation = true
  tags = {
    "Name" = "${var.default_tags.project}-public-${data.aws_availability_zones.available.names[count.index]}"
  }
  availability_zone = data.aws_availability_zones.available.names[count.index]
}

# public route table 
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags = {
    "Name" = "${var.default_tags.project}-public-route-table"
  }
}

# internet gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.default_tags.project}-internet-gateway"
  }
}

resource "aws_route" "public_internet_access" {
  route_table_id            = aws_route_table.public.id
  destination_cidr_block    = "0.0.0.0/0" #to internet
  gateway_id = aws_internet_gateway.gw.id
}

resource "aws_route_table_association" "public" {
  count = var.public_subnet_count
  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = aws_route_table.public.id  
}

# private subntes
resource "aws_subnet" "private" {
  count = var.private_subnet_count
  # block label
  vpc_id = aws_vpc.main.id 
  # set a range of subnet
  # 10.255.0.0/20 -> 10.255.0.0/24
  cidr_block = cidrsubnet(aws_vpc.main.cidr_block, 4, count.index + var.private_subnet_count) 
  tags = {
    "Name" = "${var.default_tags.project}-private-${data.aws_availability_zones.available.names[count.index]}"
  }
  availability_zone = data.aws_availability_zones.available.names[count.index]
}

# private route table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags = {
    "Name" = "${var.default_tags.project}-private-route-table"
  }
}

resource "aws_eip" "nat" {
  vpc = true
  tags = {
    "Name" = "${var.default_tags.project}-nat-eip"
  }
}

# NAT gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.0.id

  tags = {
    Name = "${var.default_tags.project}-nat"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_eip.nat, aws_internet_gateway.gw]
}

# private route table and routes
resource "aws_route" "private_internet_access" {
  route_table_id            = aws_route_table.private.id
  destination_cidr_block    = "0.0.0.0/0" #to internet
  gateway_id = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "private" {
  count = var.private_subnet_count
  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = aws_route_table.private.id  
}


