# Create a DB Subnet Group for RDS
resource "aws_db_subnet_group" "dnsdetectives_db_subnet_group" {
  name       = "dnsdetectives-db-subnet-group"
  subnet_ids = [aws_subnet.dnsdetectives_subnet1.id, aws_subnet.dnsdetectives_subnet2.id]

  tags = {
    Name = "dnsdetectivesDBSubnetGroup"
  }
}

# Security Group for RDS
resource "aws_security_group" "dnsdetectives_security_group" {
  vpc_id = aws_vpc.dnsdetectives_vpc.id
}

# RDS DB Instance
resource "aws_db_instance" "dnsdetectives_db" {
  allocated_storage    = 10
  db_name              = "dnsdetectivesdb"
  engine               = "postgres"
  engine_version       = "15"
  instance_class       = "db.t3.micro"
  username             = "dnsdetectivesmaster"
  password             = "securepass"
  parameter_group_name = "default.postgres15"
  skip_final_snapshot  = true
  publicly_accessible  = true

  vpc_security_group_ids = [aws_security_group.dnsdetectives_security_group.id]
  db_subnet_group_name   = aws_db_subnet_group.dnsdetectives_db_subnet_group.name
}
