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

variable "environment" {
  type    = string
  default = "dev"
}

data "aws_ami" "al2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*"]
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet" "web" {
  vpc_id            = data.aws_vpc.default.id
  availability_zone = "us-east-1a"
  default_for_az    = true
}

resource "random_integer" "build" {
  min = 1000
  max = 9999
}

resource "aws_security_group" "web" {
  name        = "storefront-web"
  description = "Storefront web tier"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "web" {
  for_each = toset(["a", "b", "c"])

  ami                    = data.aws_ami.al2.id
  instance_type          = "t3.micro"
  subnet_id              = data.aws_subnet.web.id
  vpc_security_group_ids = [aws_security_group.web.id]

  tags = {
    Name        = "storefront-web-${each.key}"
    Environment = var.environment
    Build       = random_integer.build.result
  }
}

resource "aws_security_group" "debug" {
  name        = "storefront-debug"
  description = "Temporary SSH access for debugging"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_instance" "debug" {
  ami                    = data.aws_ami.al2.id
  instance_type          = "t3.micro"
  subnet_id              = data.aws_subnet.web.id
  vpc_security_group_ids = [aws_security_group.debug.id]

  tags = {
    Name = "storefront-debug"
  }
}

resource "aws_s3_bucket" "artifacts" {
  bucket = "storefront-artifacts"

  tags = {
    Team = "storefront"
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

output "artifacts_tags" {
  value = aws_s3_bucket.artifacts.tags
}
