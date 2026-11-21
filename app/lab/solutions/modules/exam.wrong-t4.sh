set -euo pipefail
rm -rf modules/app
mkdir -p modules/iam modules/compute
cat > modules/iam/main.tf <<'HCL'
variable "name" {
  type = string
}

variable "policies" {
  type = list(object({
    name    = string
    actions = list(string)
  }))
}

locals {
  policies = { for p in var.policies : p.name => p }
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "access" {
  for_each = local.policies

  statement {
    actions   = each.value.actions
    resources = ["*"]
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.name}-app"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_policy" "access" {
  for_each = local.policies

  name   = "${var.name}-${each.key}"
  policy = data.aws_iam_policy_document.access[each.key].json
}

resource "aws_iam_role_policy_attachment" "access" {
  for_each = local.policies

  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.access[each.key].arn
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.name}-app"
  role = aws_iam_role.this.name
}

output "instance_profile_name" {
  value = aws_iam_instance_profile.this.name
}
HCL
cat > modules/compute/main.tf <<'HCL'
variable "name" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_ids" {
  type = list(string)
}

variable "instance_profile_name" {
  type = string
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*"]
  }
}

resource "aws_launch_template" "this" {
  name                   = "${var.name}-app"
  image_id               = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = var.security_group_ids

  iam_instance_profile {
    name = var.instance_profile_name
  }
}

resource "aws_autoscaling_group" "this" {
  name                = "${var.name}-app"
  min_size            = 1
  max_size            = 2
  desired_capacity    = 1
  vpc_zone_identifier = [var.subnet_id]

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }
}

output "asg_name" {
  value = aws_autoscaling_group.this.name
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

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet" "a" {
  vpc_id            = data.aws_vpc.default.id
  availability_zone = "us-east-1a"
  default_for_az    = true
}

module "iam" {
  source = "./modules/iam"

  name = "orders"
  policies = [
    { name = "s3-read", actions = ["s3:GetObject", "s3:ListBucket"] },
    { name = "logs-write", actions = ["logs:CreateLogStream", "logs:PutLogEvents"] },
  ]
}

module "app_sg" {
  source = "git::file:///home/coder/repos/security-group?ref=v1.1.0"

  name        = "orders-app"
  description = "orders app instances"
  vpc_id      = data.aws_vpc.default.id
  ingress = {
    https = { port = 443, cidr = "0.0.0.0/0" }
  }
}

module "compute" {
  source = "./modules/compute"

  name                  = "orders"
  subnet_id             = data.aws_subnet.a.id
  security_group_ids    = [module.app_sg.id]
  instance_profile_name = module.iam.instance_profile_name
}

output "asg_name" {
  value = module.compute.asg_name
}
HCL
terraform init -input=false -no-color

terraform plan -input=false -no-color || true
