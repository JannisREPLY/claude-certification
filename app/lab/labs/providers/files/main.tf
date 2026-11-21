terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.1.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "random_integer" "build" {
  min = 1000
  max = 9999
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "web" {
  name        = "web-${random_integer.build.result}"
  description = "Web servers"
  vpc_id      = data.aws_vpc.default.id
}

module "reports" {
  source = "./modules/reports"

  name = "acme-reports"
}
