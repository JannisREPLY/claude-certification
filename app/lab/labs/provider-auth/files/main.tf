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

data "aws_caller_identity" "current" {}

module "audit" {
  source   = "./modules/audit"
  for_each = toset(["platform", "data"])

  team = each.key
}
