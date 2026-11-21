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
  region = "us-east-1"
}

module "platform" {
  source       = "./modules/platform"
  bucket_names = ["nw-sto-manifests", "nw-sto-invoices", "nw-sto-archive"]
}

output "reader_role_arn" {
  value = module.platform.reader_role_arn
}
