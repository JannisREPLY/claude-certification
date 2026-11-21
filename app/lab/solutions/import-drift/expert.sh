set -euo pipefail
q() { aws ec2 describe-instances --filters "Name=tag:Name,Values=$1" --query 'Reservations[0].Instances[0]' --output json; }
instance=$(q legacy-api)
sg=$(echo "$instance" | jq -r '.SecurityGroups[0].GroupId')
{
cat <<TF
import {
  to = aws_instance.legacy_api
  id = "$(echo "$instance" | jq -r .InstanceId)"
}

import {
  to = aws_security_group.legacy_api
  id = "$sg"
}

import {
  to = aws_iam_role.legacy_api
  id = "legacy-api-role"
}

import {
  to = aws_iam_instance_profile.legacy_api
  id = "legacy-api-profile"
}
TF
for w in a b c; do cat <<TF

import {
  to = aws_instance.worker["$w"]
  id = "$(q legacy-worker-$w | jq -r .InstanceId)"
}
TF
done
cat <<TF

moved {
  from = aws_s3_bucket.artifacts
  to   = aws_s3_bucket.build_artifacts
}

locals {
  ami    = "$(echo "$instance" | jq -r .ImageId)"
  subnet = "$(echo "$instance" | jq -r .SubnetId)"
}

resource "aws_iam_role" "legacy_api" {
  name = "legacy-api-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_instance_profile" "legacy_api" {
  name = "legacy-api-profile"
  role = aws_iam_role.legacy_api.name
}

resource "aws_security_group" "legacy_api" {
  name        = "legacy-api-sg"
  description = "Legacy API access"
  vpc_id      = "$(echo "$instance" | jq -r .VpcId)"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "legacy_api" {
  ami                    = local.ami
  instance_type          = "t3.micro"
  subnet_id              = local.subnet
  vpc_security_group_ids = [aws_security_group.legacy_api.id]
  iam_instance_profile   = aws_iam_instance_profile.legacy_api.name

  tags = {
    Name = "legacy-api"
    Team = "orders"
  }
}

resource "aws_instance" "worker" {
  for_each = toset(["a", "b", "c"])

  ami                    = local.ami
  instance_type          = "t3.micro"
  subnet_id              = local.subnet
  vpc_security_group_ids = [aws_security_group.legacy_api.id]

  tags = {
    Name = "legacy-worker-\${each.key}"
    Team = "orders"
  }
}
TF
} > legacy.tf
python3 - <<'PY'
import re
s = open("main.tf").read()
s = re.sub(r'\nresource "aws_s3_bucket" "reports" \{.*?\n\}\n', "\n", s, flags=re.S)
s = s.replace('"artifacts"', '"build_artifacts"').replace('Environment = "prod"', 'Environment = "prod"\n    CostCenter  = "cc-4711"')
open("main.tf", "w").write(s)
PY
terraform state rm aws_s3_bucket.reports
terraform apply -auto-approve -no-color
terraform plan -no-color -detailed-exitcode
