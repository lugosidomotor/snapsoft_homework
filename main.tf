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

resource "aws_db_instance" "sample_db" {
allocated_storage = 10
db_name = "mydb"
engine = "postgres"
engine_version = "15"
instance_class = "db.t3.micro"
username = "master"
password = "securepass"
parameter_group_name = "default.postgres15"
skip_final_snapshot = true
publicly_accessible = true
}

################## Lambda code ##################

resource "aws_s3_bucket" "lambda_code_bucket" {
  bucket = "dnsdetectives-lambda-code-bucket"
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
  name = "lambda_execution_role"

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

resource "aws_lambda_function" "example" {
  function_name    = "example_lambda_function"
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

resource "aws_api_gateway_rest_api" "example" {
  name        = "example_api"
  description = "API Gateway for Lambda example"
}

resource "aws_api_gateway_resource" "example_resource" {
  rest_api_id = aws_api_gateway_rest_api.example.id
  parent_id   = aws_api_gateway_rest_api.example.root_resource_id
  path_part   = "example-path"
}

resource "aws_api_gateway_method" "example_method" {
  rest_api_id   = aws_api_gateway_rest_api.example.id
  resource_id   = aws_api_gateway_resource.example_resource.id
  http_method   = "GET"   // Or POST, depending on your Lambda function
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.example.id
  resource_id = aws_api_gateway_resource.example_resource.id
  http_method = aws_api_gateway_method.example_method.http_method
  integration_http_method = "POST"
  type        = "AWS_PROXY"
  uri         = aws_lambda_function.example.invoke_arn
}

resource "aws_api_gateway_deployment" "example_deployment" {
  depends_on = [aws_api_gateway_integration.lambda_integration]

  rest_api_id = aws_api_gateway_rest_api.example.id
  stage_name  = "test"
}

