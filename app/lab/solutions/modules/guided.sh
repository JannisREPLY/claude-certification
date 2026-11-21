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
  count = length(var.policies)

  statement {
    actions   = var.policies[count.index].actions
    resources = ["*"]
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.name}-app"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_policy" "access" {
  count = length(var.policies)

  name   = "${var.name}-${var.policies[count.index].name}"
  policy = data.aws_iam_policy_document.access[count.index].json
}

resource "aws_iam_role_policy_attachment" "access" {
  count = length(var.policies)

  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.access[count.index].arn
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
cat > moved.tf <<'HCL'
moved {
  from = module.app.aws_iam_role.this
  to   = module.iam.aws_iam_role.this
}

moved {
  from = module.app.aws_iam_instance_profile.this
  to   = module.iam.aws_iam_instance_profile.this
}

moved {
  from = module.app.aws_iam_policy.access[0]
  to   = module.iam.aws_iam_policy.access[0]
}

moved {
  from = module.app.aws_iam_policy.access[1]
  to   = module.iam.aws_iam_policy.access[1]
}

moved {
  from = module.app.aws_iam_role_policy_attachment.access[0]
  to   = module.iam.aws_iam_role_policy_attachment.access[0]
}

moved {
  from = module.app.aws_iam_role_policy_attachment.access[1]
  to   = module.iam.aws_iam_role_policy_attachment.access[1]
}

moved {
  from = module.app.aws_security_group.this
  to   = module.app_sg.aws_security_group.this
}

moved {
  from = module.app.aws_vpc_security_group_ingress_rule.https
  to   = module.app_sg.aws_vpc_security_group_ingress_rule.this["https"]
}

moved {
  from = module.app.aws_launch_template.this
  to   = module.compute.aws_launch_template.this
}

moved {
  from = module.app.aws_autoscaling_group.this
  to   = module.compute.aws_autoscaling_group.this
}
HCL
terraform init -input=false -no-color
terraform apply -auto-approve -input=false -no-color
terraform plan -input=false -no-color -detailed-exitcode
