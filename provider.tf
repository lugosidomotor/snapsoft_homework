provider "aws" {
  region = "us-west-2"
  default_tags {
    tags = {
      Terraform   = "true"
      Environment = local.Environment
      Company     = local.Company
    }
  }
}

# Random Provider for Password Generation
terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
