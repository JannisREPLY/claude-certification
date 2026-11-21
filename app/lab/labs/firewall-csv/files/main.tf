terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = "us-east-1"
  profile = "northwind-prod"
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "app" {
  name        = "nw-fw-app"
  description = "Northwind Logistics app tier"
  vpc_id      = data.aws_vpc.default.id
}
