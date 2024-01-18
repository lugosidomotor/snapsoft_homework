terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
  
  backend "s3" {
   bucket = "dnsdetectivesterraformstate"
   key    = "dnsdetectivesterraformstate"
   region = "eu-central-1"
  }
}

locals {
  Environment = "dev"
}

provider "aws" {
  region = "eu-central-1"
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



