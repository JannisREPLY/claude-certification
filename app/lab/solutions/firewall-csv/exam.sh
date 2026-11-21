set -euo pipefail
cat > main.tf <<'TF'
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

variable "environment" {
  type = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}

variable "admin_cidr" {
  type = string

  validation {
    condition     = can(cidrhost(var.admin_cidr, 0))
    error_message = "admin_cidr must be a valid CIDR block."
  }
}

variable "instances" {
  type = map(object({
    instance_type     = string
    availability_zone = string
  }))
}

locals {
  rules      = { for r in csvdecode(file("${path.module}/rules.csv")) : r.name => r }
  statements = jsondecode(file("${path.module}/policy.json"))
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "app" {
  name        = "nw-fw-app"
  description = "Northwind Logistics app tier"
  vpc_id      = data.aws_vpc.default.id

  tags = {
    Environment = var.environment
  }
}

resource "aws_vpc_security_group_ingress_rule" "app" {
  for_each          = local.rules
  security_group_id = aws_security_group.app.id
  ip_protocol       = each.value.protocol
  from_port         = tonumber(each.value.port)
  to_port           = tonumber(each.value.port)
  cidr_ipv4         = each.value.cidr == "admin" ? var.admin_cidr : each.value.cidr
  description       = each.value.description
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*"]
  }
}

data "aws_subnet" "app" {
  for_each          = var.instances
  vpc_id            = data.aws_vpc.default.id
  availability_zone = each.value.availability_zone
  default_for_az    = true
}

resource "aws_instance" "app" {
  for_each               = var.instances
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = each.value.instance_type
  subnet_id              = data.aws_subnet.app[each.key].id
  vpc_security_group_ids = [aws_security_group.app.id]

  tags = {
    Name        = "nw-fw-${each.key}"
    Environment = var.environment
  }

  lifecycle {
    precondition {
      condition     = contains(["t3.micro", "t3.small"], each.value.instance_type)
      error_message = "Only t3.micro and t3.small are approved for the app tier."
    }
  }
}

data "aws_iam_policy_document" "app" {
  dynamic "statement" {
    for_each = local.statements

    content {
      sid       = statement.value.sid
      effect    = statement.value.effect
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

resource "aws_iam_policy" "app" {
  name   = "nw-fw-app-policy"
  policy = data.aws_iam_policy_document.app.json
}

output "tcp_ports" {
  value = [for p in sort(distinct([for r in local.rules : format("%05d", tonumber(r.port)) if r.protocol == "tcp"])) : tonumber(p)]
}

output "public_rule_names" {
  value = sort([for r in local.rules : r.name if r.cidr == "0.0.0.0/0"])
}

output "instance_private_ips" {
  value = { for k, i in aws_instance.app : k => i.private_ip }
}
TF
terraform init -input=false -no-color
terraform apply -auto-approve -input=false -no-color
terraform plan -input=false -no-color -detailed-exitcode
