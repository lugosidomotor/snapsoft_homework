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
    bucket = "${var.company}-terraform-state-${var.environment}"
    key    = "${var.company}-terraform-state-${var.environment}"
  }
}
