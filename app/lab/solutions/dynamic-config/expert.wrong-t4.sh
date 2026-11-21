set -euo pipefail
sed -i 's/"~> 1.5.0"/"~> 1.6"/; s/">= 4.0, < 5.0"/"~> 5.0"/' main.tf
cat > variables.tf <<'HCL'
variable "instances" {
  type = map(object({
    instance_type = optional(string, "t3.micro")
    subnet_index  = optional(number, 0)
    role          = optional(string, "worker")
    enabled       = optional(bool, true)
    tags          = optional(map(string), {})
  }))
}
HCL
cat > web.tf <<'HCL'
locals {
  config = yamldecode(file("${path.module}/rules.yaml"))

  yaml_rules = [
    for r in local.config.rules : {
      name     = r.name
      protocol = try(r.protocol, "tcp")
      port     = r.port
      to_port  = try(r.to_port, r.port)
      cidrs    = r.cidrs
    } if try(r.enabled, true)
  ]

  yaml_map = merge([
    for r in local.yaml_rules : {
      for c in r.cidrs : "${r.name}-${c}" => { protocol = r.protocol, port = r.port, to_port = r.to_port, cidr = c }
    }
  ]...)

  csv_map = {
    for r in csvdecode(file("${path.module}/partner-rules.csv")) :
    "${r.name}-${r.cidr}" => { protocol = r.protocol, port = tonumber(r.port), to_port = tonumber(r.port), cidr = r.cidr }
  }

  rules        = merge(local.yaml_map, local.csv_map)
  public_cidrs = ["0.0.0.0/0", "::/0"]
  instances    = { for k, v in var.instances : k => v if v.enabled }
  public_ports = distinct([for r in local.rules : r.port if r.protocol == "tcp" && contains(local.public_cidrs, r.cidr)])
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
  to_port           = each.value.to_port
  ip_protocol       = each.value.protocol
  cidr_ipv4         = strcontains(each.value.cidr, ":") ? null : each.value.cidr
  cidr_ipv6         = strcontains(each.value.cidr, ":") ? each.value.cidr : null
}

resource "aws_instance" "app" {
  for_each = local.instances

  ami                    = data.aws_ami.al2.id
  instance_type          = each.value.instance_type
  subnet_id              = element(sort(data.aws_subnets.default.ids), each.value.subnet_index)
  vpc_security_group_ids = [aws_security_group.web.id]

  tags = merge(each.value.tags, { Name = each.key, Role = each.value.role })
}

output "public_tcp_ports" {
  value = sort(local.public_ports)
}

output "admin_cidrs" {
  value = sort(distinct([for r in local.rules : r.cidr if r.port <= 22 && r.to_port >= 22]))
}

output "private_ips" {
  value = { for k, i in aws_instance.app : k => i.private_ip }
}

output "instances_by_role" {
  value = { for k, v in local.instances : v.role => k... }
}
HCL
terraform apply -auto-approve -no-color
terraform plan -no-color -detailed-exitcode
