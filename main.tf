terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
  
  backend "s3" {
   bucket = "dnsdetectives-terraform-state"
   key    = "dnsdetectives-terraform-state"
   region = "us-west-2"
  }
}

locals {
  Environment = "dev"
}

provider "aws" {
  region = "us-west-2"
  default_tags {
    tags = {
      Terraform   = "true"
      Environment = local.Environment
    }
  }

}

################## RDS ##################

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

# Create a DB Subnet Group for RDS
resource "aws_db_subnet_group" "dnsdetectives_db_subnet_group" {
  name       = "dnsdetectives-db-subnet-group"
  subnet_ids = [aws_subnet.dnsdetectives_subnet1.id, aws_subnet.dnsdetectives_subnet2.id]

  tags = {
    Name = "dnsdetectivesDBSubnetGroup"
  }
}

# Security Group for RDS (if needed)
resource "aws_security_group" "dnsdetectives_security_group" {
  vpc_id = aws_vpc.dnsdetectives_vpc.id

  # Add your desired ingress and egress rules
}

# RDS DB Instance
resource "aws_db_instance" "dnsdetectives_db" {
  allocated_storage    = 10
  db_name              = "dnsdetectivesdb"
  engine               = "postgres"
  engine_version       = "15"
  instance_class       = "db.t3.micro"
  username             = "dnsdetectivesmaster"
  password             = "securepass"  # Ensure to use a secure method to handle passwords
  parameter_group_name = "default.postgres15"
  skip_final_snapshot  = true
  publicly_accessible  = true

  vpc_security_group_ids = [aws_security_group.dnsdetectives_security_group.id]
  db_subnet_group_name   = aws_db_subnet_group.dnsdetectives_db_subnet_group.name

  tags = {
    Name = "dnsdetectivesDBInstance"
  }
}

################## Lambda code ##################

resource "aws_s3_bucket" "lambda_code_bucket" {
  bucket = "dnsdetectives-lambda-code"
  // Removed ACL configuration
}

resource "null_resource" "zip_lambda_function" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = <<EOT
      cd ${path.module}
      zip -r lambda.zip lambda.js node_modules
    EOT
  }
}

resource "aws_s3_object" "lambda_code" {
  bucket = aws_s3_bucket.lambda_code_bucket.bucket
  key    = "lambda-${timestamp()}.zip"
  source = "${path.module}/lambda.zip"

  depends_on = [null_resource.zip_lambda_function]
}

################## Lambda Function ##################

resource "aws_iam_role" "lambda_execution_role" {
  name = "dnsdetectives_lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
    }]
  })
}

resource "aws_lambda_function" "dnsdetectives_lambda_function" {
  function_name    = "dnsdetectives_lambda_function"
  s3_bucket        = aws_s3_bucket.lambda_code_bucket.bucket
  s3_key           = aws_s3_object.lambda_code.key
  handler          = "lambda.handler"
  runtime          = "nodejs18.x"
  role             = aws_iam_role.lambda_execution_role.arn

  environment {
    variables = {
      DB_HOST     = aws_db_instance.dnsdetectives_db.address
      DB_USER     = aws_db_instance.dnsdetectives_db.username
      DB_PASSWORD = aws_db_instance.dnsdetectives_db.password
      DB_NAME     = aws_db_instance.dnsdetectives_db.db_name
    }
  }

  depends_on = [null_resource.zip_lambda_function]
}

################## API Gateway ##################

resource "aws_api_gateway_rest_api" "dnsdetectives_api" {
  name        = "dnsdetectives_api"
  description = "API Gateway for Lambda example"
}

resource "aws_api_gateway_resource" "dnsdetectives_resource" {
  rest_api_id = aws_api_gateway_rest_api.dnsdetectives_api.id
  parent_id   = aws_api_gateway_rest_api.dnsdetectives_api.root_resource_id
  path_part   = "dnsdetectives-path"
}

resource "aws_api_gateway_method" "dnsdetectives_method" {
  rest_api_id   = aws_api_gateway_rest_api.dnsdetectives_api.id
  resource_id   = aws_api_gateway_resource.dnsdetectives_resource.id
  http_method   = "POST"   // Or POST, depending on your Lambda function
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "dnsdetectives_lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.dnsdetectives_api.id
  resource_id = aws_api_gateway_resource.dnsdetectives_resource.id
  http_method = aws_api_gateway_method.dnsdetectives_method.http_method
  integration_http_method = "POST"
  type        = "AWS_PROXY"
  uri         = aws_lambda_function.dnsdetectives_lambda_function.invoke_arn
}

resource "aws_api_gateway_deployment" "dnsdetectives_deployment" {
  depends_on = [aws_api_gateway_integration.dnsdetectives_lambda_integration]

  rest_api_id = aws_api_gateway_rest_api.dnsdetectives_api.id
  stage_name  = "test"
}

