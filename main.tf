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
  Company     = "dnsdetectives"
}
