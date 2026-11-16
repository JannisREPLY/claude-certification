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

resource "aws_security_group" "this" {
  name        = var.name
  description = var.description
  vpc_id      = var.vpc_id
}

output "id" {
  value = aws_security_group.this.id
}
