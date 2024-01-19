# Create a DB Subnet Group for RDS
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "${var.company}_${var.environment}_dbsubnetgroup"
  subnet_ids = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]

  tags = {
    Name = "${var.company}-${var.environment}-DBSubnetGroup"
  }
}

# Security Group for RDS
resource "aws_security_group" "security_group" {
  vpc_id = aws_vpc.vpc.id
}

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

# RDS DB Instance
resource "aws_db_instance" "db_instance" {
  allocated_storage    = 10
  db_name              = "${var.company}-${var.environment}db"
  engine               = "postgres"
  engine_version       = "15"
  instance_class       = "db.t3.micro"
  username             = "${var.company}-${var.environment}-master"
  password             = random_password.password.result
  parameter_group_name = "default.postgres15"
  skip_final_snapshot  = true
  publicly_accessible  = true

  vpc_security_group_ids = [aws_security_group.security_group.id]
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
}
