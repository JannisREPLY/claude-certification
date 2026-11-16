variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

resource "aws_security_group" "this" {
  name        = var.name
  description = "Managed by Terraform"
  vpc_id      = var.vpc_id
}

output "id" {
  value = aws_security_group.this.id
}
