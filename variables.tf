variable "aws_region" {
  description = "The AWS region to deploy resources into"
  type        = string
}

variable "Environment" {
  description = "The deployment environment"
  type        = string
  default     = "dev"
}

variable "Company" {
  description = "The company name"
  type        = string
  default     = "dnsdetectives"
}

