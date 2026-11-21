variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "policies" {
  type = list(object({
    name    = string
    actions = list(string)
  }))
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*"]
  }
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

resource "aws_security_group" "this" {
  name        = "${var.name}-app"
  description = "${var.name} app instances"
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  security_group_id = aws_security_group.this.id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_launch_template" "this" {
  name                   = "${var.name}-app"
  image_id               = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.this.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.this.name
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
