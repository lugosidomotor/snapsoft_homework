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

provider "aws" {
  region = "us-west-2"  # Change to your desired AWS region
}

# Create a new VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "MyVPC"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.my_vpc.id
}

# Create two subnets (one in each availability zone for high availability)
resource "aws_subnet" "subnet1" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-west-2a"
  map_public_ip_on_launch = true  # For public subnet

  tags = {
    Name = "Subnet1"
  }
}

resource "aws_subnet" "subnet2" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-west-2b"
  map_public_ip_on_launch = true  # For public subnet

  tags = {
    Name = "Subnet2"
  }
}

# Create a route table and associate it with the subnets
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "rta1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "rta2" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.rt.id
}

# Create a DB Subnet Group for RDS
resource "aws_db_subnet_group" "my_db_subnet_group" {
  name       = "my-db-subnet-group"
  subnet_ids = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]

  tags = {
    Name = "MyDBSubnetGroup"
  }
}

# Security Group for RDS (if needed)
resource "aws_security_group" "my_security_group" {
  vpc_id = aws_vpc.my_vpc.id

  # Add your desired ingress and egress rules
}


################## Lambda code ##################

resource "aws_s3_bucket" "lambda_code_bucket" {
  bucket = "dnsdetectives-lambda-code"
  // Removed ACL configuration
}

resource "null_resource" "zip_lambda_function" {
  provisioner "local-exec" {
    command = "zip lambda.zip lambda.js"
    working_dir = path.module
  }

  triggers = {
    always_run = "${timestamp()}"
  }
}

resource "aws_s3_object" "lambda_code" {
  bucket = aws_s3_bucket.lambda_code_bucket.bucket
  key    = "lambda.zip"
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
  handler          = "lambda.handler" // Update with the correct handler
  runtime          = "nodejs12.x"     // Update with the correct runtime
  role             = aws_iam_role.lambda_execution_role.arn

  environment {
    variables = {
      DB_HOST     = aws_db_instance.sample_db.address
      DB_USER     = aws_db_instance.sample_db.username
      DB_PASSWORD = aws_db_instance.sample_db.password
      DB_NAME     = aws_db_instance.sample_db.db_name
    }
  }
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
  http_method   = "GET"   // Or POST, depending on your Lambda function
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "dnsdetectives_lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.dnsdetectives_api.id
  resource_id = aws_api_gateway_resource.dnsdetectives_resource.id
  http_method = aws_api_gateway_method.dnsdetectives_method.http_method
  integration_http_method = "POST"
  type        = "AWS_PROXY"
  uri         = aws_lambda_function.dnsdetectives.invoke_arn
}

resource "aws_api_gateway_deployment" "dnsdetectives_deployment" {
  depends_on = [aws_api_gateway_integration.dnsdetectives_lambda_integration]

  rest_api_id = aws_api_gateway_rest_api.dnsdetectives_api.id
  stage_name  = "test"
}

