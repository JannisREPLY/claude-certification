set -euo pipefail
q() { aws ec2 describe-instances --filters "Name=tag:Name,Values=$1" Name=instance-state-name,Values=running --query 'Reservations[0].Instances[0]' --output json; }
web1=$(q nw-bf-web-1)
web2=$(q nw-bf-web-2)
sg=$(echo "$web1" | jq -r '.SecurityGroups[0].GroupId')
cat > web.tf <<TF
import {
  to = aws_instance.web["web-1"]
  id = "$(echo "$web1" | jq -r .InstanceId)"
}

import {
  to = aws_instance.web["web-2"]
  id = "$(echo "$web2" | jq -r .InstanceId)"
}

import {
  to = aws_security_group.web
  id = "$sg"
}

import {
  to = aws_iam_role.web
  id = "nw-bf-web-role"
}

import {
  to = aws_iam_instance_profile.web
  id = "nw-bf-web-profile"
}

data "aws_iam_policy_document" "web_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "web" {
  name               = "nw-bf-web-role"
  assume_role_policy = data.aws_iam_policy_document.web_assume.json
}

resource "aws_iam_instance_profile" "web" {
  name = "nw-bf-web-profile"
  role = aws_iam_role.web.name
}

resource "aws_security_group" "web" {
  name        = "nw-bf-web-sg"
  description = "Dispatch web access"
  vpc_id      = data.aws_vpc.default.id

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

resource "aws_instance" "web" {
  for_each = toset(["web-1", "web-2"])

  ami                    = "$(echo "$web1" | jq -r .ImageId)"
  instance_type          = "t3.micro"
  subnet_id              = "$(echo "$web1" | jq -r .SubnetId)"
  vpc_security_group_ids = [aws_security_group.web.id]
  iam_instance_profile   = aws_iam_instance_profile.web.name

  tags = {
    Name = "nw-bf-\${each.key}"
    Team = "dispatch"
  }
}

moved {
  from = aws_s3_bucket.manifests
  to   = aws_s3_bucket.shipping_manifests
}
TF
python3 - <<'PY'
import re
s = open("main.tf").read()
s = s.replace('''  tags = {
    Team = "dispatch"
  }
}

resource "aws_s3_bucket" "manifests"''', '''  tags = {
    Team  = "dispatch"
    Owner = "dispatch-oncall"
  }
}

resource "aws_s3_bucket" "shipping_manifests"''')
s = re.sub(r'\nresource "aws_s3_bucket" "legacy_exports" \{.*?\n\}\n', "", s, flags=re.S)
open("main.tf", "w").write(s)
PY

terraform apply -auto-approve -no-color
cat > backend.tf <<'HCL'
terraform {
  backend "s3" {
    bucket         = "nw-bf-tfstate"
    key            = "brownfield/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "nw-bf-tf-locks"
    encrypt        = true
  }
}
HCL
terraform init -migrate-state -force-copy -input=false -no-color
rm -f terraform.tfstate terraform.tfstate.backup
terraform plan -no-color -detailed-exitcode
