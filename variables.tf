variable "aws_region" {
  description = "The AWS region to deploy resources into"
  type        = string
}

variable environment" {
  description = "The deployment environment"
  type        = string
  default     = "dev"
}

variable "company" {
  description = "The company name"
  type        = string
  default     = "dnsdetectives"
}

