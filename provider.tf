provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Terraform   = "true"
      Environment = vars.environment
      Company     = vars.company
    }
  }
}
