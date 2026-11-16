terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "app" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name        = "app-vpc"
    Environment = "dev"
  }
}

resource "aws_subnet" "app" {
  vpc_id     = aws_vpc.app.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "app-subnet"
  }
}
