terraform {
  required_version = ">= 1.6.0"

  backend "s3" {
    bucket = "payments-tfstate"
    key    = "payments/terraform.tfstate"
    region = "us-east-1"
  }

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

variable "app_version" {
  type        = string
  description = "Version of the payments service to release."

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.app_version))
    error_message = "app_version must be a semantic version such as 1.4.2."
  }
}

variable "channel" {
  type    = string
  default = "stable"
}

resource "aws_s3_bucket" "releases" {
  bucket = "payments-releases"

  tags = {
    Team = "payments"
  }
}

resource "aws_s3_object" "release" {
  bucket       = aws_s3_bucket.releases.id
  key          = "${var.channel}/release.json"
  content      = jsonencode({ service = "payments", version = var.app_version })
  content_type = "application/json"
}
