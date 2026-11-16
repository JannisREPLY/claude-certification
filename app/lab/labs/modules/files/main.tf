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

variable "subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "main"
  }
}

resource "aws_subnet" "public" {
  count = length(var.subnet_cidrs)

  vpc_id     = aws_vpc.main.id
  cidr_block = var.subnet_cidrs[count.index]
}

resource "aws_security_group" "web" {
  name        = "web"
  description = "Web access"
  vpc_id      = aws_vpc.main.id
}
