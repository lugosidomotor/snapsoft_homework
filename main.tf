terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    bucket = "dnsdetectives-terraform-state-dev"
    key    = "dnsdetectives-terraform-state-dev"
    region = var.aws_region
  }
}

locals {
  Environment = "dev"
  Company     = "dnsdetectives"
}
