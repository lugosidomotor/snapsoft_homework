terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
  
  backend "s3" {
   bucket = "dnsdetectives-terraform-state-dev"
   key    = "dnsdetectives-terraform-state-dev"
   region = "us-west-2"
  }
}

locals {
  Environment = "dev"
  Company     = "dnsdetectives"
}
