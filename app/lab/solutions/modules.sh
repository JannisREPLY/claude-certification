set -euo pipefail
mkdir -p modules/network
cat > modules/network/main.tf <<'HCL'
variable "cidr_block" {
  type = string
}

variable "subnet_cidrs" {
  type = list(string)
}

resource "aws_vpc" "this" {
  cidr_block = var.cidr_block

  tags = {
    Name = "main"
  }
}

resource "aws_subnet" "this" {
  for_each = toset(var.subnet_cidrs)

  vpc_id     = aws_vpc.this.id
  cidr_block = each.value
}

output "vpc_id" {
  value = aws_vpc.this.id
}

output "subnet_ids" {
  value = [for s in aws_subnet.this : s.id]
}
HCL
cat > main.tf <<'HCL'
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

module "network" {
  source       = "./modules/network"
  cidr_block   = "10.0.0.0/16"
  subnet_cidrs = var.subnet_cidrs
}

module "web_sg" {
  source      = "git::file:///home/coder/repos/web-sg?ref=v1.1.0"
  name        = "web"
  description = "Web access"
  vpc_id      = module.network.vpc_id
}

moved {
  from = aws_vpc.main
  to   = module.network.aws_vpc.this
}

moved {
  from = aws_subnet.public[0]
  to   = module.network.aws_subnet.this["10.0.1.0/24"]
}

moved {
  from = aws_subnet.public[1]
  to   = module.network.aws_subnet.this["10.0.2.0/24"]
}

moved {
  from = aws_security_group.web
  to   = module.web_sg.aws_security_group.this
}
HCL
terraform init -input=false -no-color
terraform apply -auto-approve -no-color
