set -euo pipefail
cat > web.tf <<'HCL'
locals {
  config = yamldecode(file("${path.module}/rules.yaml"))
  rules  = { for r in local.config.rules : r.name => r }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ami" "al2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_security_group" "web" {
  name        = local.config.security_group.name
  description = local.config.security_group.description
  vpc_id      = data.aws_vpc.default.id
}

resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = local.rules

  security_group_id = aws_security_group.web.id
  from_port         = each.value.port
  to_port           = each.value.port
  ip_protocol       = each.value.protocol
  cidr_ipv4         = each.value.cidr
}

resource "aws_instance" "app" {
  for_each = var.instances

  ami                    = data.aws_ami.al2.id
  instance_type          = each.value.instance_type
  subnet_id              = sort(data.aws_subnets.default.ids)[each.value.subnet_index]
  vpc_security_group_ids = [aws_security_group.web.id]

  tags = merge(each.value.tags, { Name = each.key })
}

output "public_tcp_ports" {
  value = sort(distinct([for r in local.config.rules : r.port if r.protocol == "tcp" && r.cidr == "0.0.0.0/0"]))
}

output "private_ips" {
  value = { for k, i in aws_instance.app : k => i.private_ip }
}
HCL
terraform apply -auto-approve -no-color
terraform plan -no-color -detailed-exitcode
