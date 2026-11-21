terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_vpc" "default" {
  default = true
}

locals {
  app_port = 443
}

resource "aws_s3_bucket" "primary" {
  bucket = "nw-dr-primary-data"
}

resource "aws_security_group" "app" {
  name        = "nw-dr-app-sg"
  description = "Order API"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = local.app_port
    to_port     = local.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

module "backup" {
  source = "./modules/backup"

  primary_bucket = aws_s3_bucket.primary.bucket
  app_port       = local.app_port
}
