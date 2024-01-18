terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
  
  backend "s3" {
   bucket = "DnsDetectivesState"
   key    = "DnsDetectivesState"
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

resource "aws_db_instance" "example" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "postgres"
  engine_version       = "12.4"
  instance_class       = "db.t3.micro"
  name                 = "mydb"
  username             = "user"
  password             = "password"
  parameter_group_name = "default.postgres12"
  skip_final_snapshot  = true
}
