variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "description" {
  type    = string
  default = "Managed by Terraform"
}

variable "ingress" {
  type = map(object({
    port = number
    cidr = string
  }))
  default = {}
}

resource "aws_security_group" "this" {
  name_prefix = "${var.name}-"
  description = var.description
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = var.ingress

  security_group_id = aws_security_group.this.id
  from_port         = each.value.port
  to_port           = each.value.port
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value.cidr
}

output "id" {
  value = aws_security_group.this.id
}
