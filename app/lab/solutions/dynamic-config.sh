set -euo pipefail
python3 - <<'PY'
s = open("variables.tf").read()
s = s.replace('variable "environment" {\n  type = string\n}', '''variable "environment" {
  type = string

  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "environment must be one of dev, stage, prod."
  }
}''')
open("variables.tf", "w").write(s)
PY
cat > network.tf <<'HCL'
data "aws_vpc" "shared" {
  tags = {
    Name = "shared-vpc"
  }
}

resource "aws_subnet" "this" {
  for_each = var.subnets

  vpc_id                  = data.aws_vpc.shared.id
  cidr_block              = each.value.cidr
  map_public_ip_on_launch = each.value.public

  tags = {
    Name = "${var.environment}-${each.key}"
  }
}

resource "aws_security_group" "web" {
  name   = "${var.environment}-web"
  vpc_id = data.aws_vpc.shared.id

  dynamic "ingress" {
    for_each = var.ingress_ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}

output "subnet_ids" {
  value = { for k, s in aws_subnet.this : k => s.id }
}

output "public_subnet_ids" {
  value = [for k, s in aws_subnet.this : s.id if var.subnets[k].public]
}
HCL
terraform apply -auto-approve -no-color
