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

data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "tracker" {
  name        = "nw-bf-tracker-sg"
  description = "Shipment tracker"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Team = "dispatch"
  }
}

resource "aws_s3_bucket" "manifests" {
  bucket = "nw-bf-manifests"

  tags = {
    Team = "dispatch"
  }
}

resource "aws_s3_bucket" "legacy_exports" {
  bucket = "nw-bf-legacy-exports"

  tags = {
    Team = "dispatch"
  }
}
