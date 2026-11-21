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

data "aws_subnet" "a" {
  vpc_id            = data.aws_vpc.default.id
  availability_zone = "us-east-1a"
  default_for_az    = true
}

module "app" {
  source = "./modules/app"

  name      = "orders"
  vpc_id    = data.aws_vpc.default.id
  subnet_id = data.aws_subnet.a.id
  policies = [
    { name = "s3-read", actions = ["s3:GetObject", "s3:ListBucket"] },
    { name = "logs-write", actions = ["logs:CreateLogStream", "logs:PutLogEvents"] },
  ]
}

output "asg_name" {
  value = module.app.asg_name
}
