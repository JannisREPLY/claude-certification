provider "aws" {
  region = "us-east-1"
}

variable "team" {
  type = string
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "auditor" {
  name = "${var.team}-auditor"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
      Action    = "sts:AssumeRole"
    }]
  })
}

output "deployer" {
  value = data.aws_caller_identity.current.arn
}
