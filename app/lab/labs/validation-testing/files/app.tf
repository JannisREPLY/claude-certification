data "aws_vpc" "default" {
  default = true
}

data "aws_ami" "report" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = [var.ami_name_filter]
  }
}

resource "aws_security_group" "report" {
  name_prefix = "orders-report-"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }
}

resource "aws_instance" "report" {
  ami                    = data.aws_ami.report.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.report.id]

  tags = {
    Name        = "orders-report"
    Environment = var.environment
  }
}

resource "aws_s3_bucket" "config" {
  bucket = var.bucket_name
}

resource "aws_s3_object" "db_config" {
  bucket = aws_s3_bucket.config.id
  key    = "config/db.json"
  content = jsonencode({
    host     = "db.orders.internal"
    username = var.db_username
    password = var.db_password
  })
}
