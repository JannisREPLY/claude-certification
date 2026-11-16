terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "name" {
  type = string
}

resource "aws_cloudwatch_log_group" "this" {
  name              = var.name
  retention_in_days = 14
}
