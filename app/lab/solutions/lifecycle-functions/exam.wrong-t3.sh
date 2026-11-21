set -euo pipefail
cat > worker.tf <<'HCL'
resource "aws_launch_template" "worker" {
  name                   = "orders-worker"
  image_id               = data.aws_ami.al2.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.worker.id]
  user_data = base64encode(templatefile("${path.module}/worker.sh.tftpl", {
    environment = var.environment
    packages    = var.packages
  }))

  iam_instance_profile {
    name = aws_iam_instance_profile.worker.name
  }
}

resource "aws_autoscaling_group" "worker" {
  name                = "orders-workers"
  min_size            = 1
  max_size            = 6
  desired_capacity    = 2
  vpc_zone_identifier = data.aws_subnets.default.ids

  launch_template {
    id      = aws_launch_template.worker.id
    version = aws_launch_template.worker.latest_version
  }

  depends_on = [aws_iam_role_policy_attachment.worker]

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

resource "random_integer" "suffix" {
  min = 1000
  max = 9999
}

resource "aws_security_group" "worker" {
  name   = "orders-worker-${random_integer.suffix.result}"
  vpc_id = data.aws_vpc.default.id

}

resource "aws_vpc_security_group_ingress_rule" "worker" {
  for_each = { for pair in setproduct(var.worker_ports, var.trusted_cidrs) : "${pair[0]}-${pair[1]}" => pair }

  security_group_id = aws_security_group.worker.id
  ip_protocol       = "tcp"
  from_port         = each.value[0]
  to_port           = each.value[0]
  cidr_ipv4         = each.value[1]
}

variable "enable_canary" {
  type    = bool
  default = true
}

resource "aws_instance" "canary" {
  count = var.enable_canary ? 1 : 0

  ami                    = data.aws_ami.al2.id
  instance_type          = var.instance_type
  subnet_id              = sort(data.aws_subnets.default.ids)[0]
  vpc_security_group_ids = [aws_security_group.worker.id]

  lifecycle {
    replace_triggered_by = [aws_launch_template.worker.latest_version]
  }
}

output "canary_private_ip" {
  value = one(aws_instance.canary[*].private_ip)
}
HCL
terraform apply -auto-approve -no-color
terraform plan -no-color -detailed-exitcode
