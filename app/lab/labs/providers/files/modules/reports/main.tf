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

resource "aws_s3_bucket" "primary" {
  bucket = "${var.name}-east"

  tags = {
    Team = "reports"
  }
}

output "primary_bucket" {
  value = aws_s3_bucket.primary.bucket
}
