# Create a new VPC
resource "aws_vpc" "dnsdetectives_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "dnsdetectivesVPC"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "dnsdetectives_gw" {
  vpc_id = aws_vpc.dnsdetectives_vpc.id
}

# Create two subnets (one in each availability zone for high availability)
resource "aws_subnet" "dnsdetectives_subnet1" {
  vpc_id            = aws_vpc.dnsdetectives_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-west-2a"
  map_public_ip_on_launch = true  # For public subnet

  tags = {
    Name = "dnsdetectivesSubnet1"
  }
}

resource "aws_subnet" "dnsdetectives_subnet2" {
  vpc_id            = aws_vpc.dnsdetectives_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-west-2b"
  map_public_ip_on_launch = true  # For public subnet

  tags = {
    Name = "dnsdetectivesSubnet2"
  }
}

# Create a route table and associate it with the subnets
resource "aws_route_table" "dnsdetectives_rt" {
  vpc_id = aws_vpc.dnsdetectives_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dnsdetectives_gw.id
  }
}

resource "aws_route_table_association" "dnsdetectives_rta1" {
  subnet_id      = aws_subnet.dnsdetectives_subnet1.id
  route_table_id = aws_route_table.dnsdetectives_rt.id
}

resource "aws_route_table_association" "dnsdetectives_rta2" {
  subnet_id      = aws_subnet.dnsdetectives_subnet2.id
  route_table_id = aws_route_table.dnsdetectives_rt.id
}
