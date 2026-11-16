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

resource "random_pet" "suffix" {}

resource "aws_vpc" "primary" {
  cidr_block = "10.10.0.0/16"

  tags = {
    Name = "primary-${random_pet.suffix.id}"
  }
}

module "logs" {
  source = "./modules/logs"
  name   = "app-${random_pet.suffix.id}"
}
