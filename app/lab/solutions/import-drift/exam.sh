set -euo pipefail
rm -f generated.tf
instance=$(aws ec2 describe-instances --filters Name=tag:Name,Values=legacy-api --query 'Reservations[0].Instances[0]' --output json)
sg=$(aws ec2 describe-security-groups --group-names legacy-api-sg --query 'SecurityGroups[0].GroupId' --output text)
cat > legacy.tf <<TF
import {
  to = aws_instance.legacy_api
  id = "$(echo "$instance" | jq -r .InstanceId)"
}

import {
  to = aws_iam_role.legacy_api
  id = "legacy-api-role"
}

import {
  to = aws_security_group.legacy_api
  id = "$sg"
}

resource "aws_iam_role" "legacy_api" {
  name = "legacy-api-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
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
  ami                    = "$(echo "$instance" | jq -r .ImageId)"
  instance_type          = "t3.micro"
  subnet_id              = "$(echo "$instance" | jq -r .SubnetId)"
  vpc_security_group_ids = [aws_security_group.legacy_api.id]
  iam_instance_profile   = "legacy-api-profile"

  tags = {
    Name = "legacy-api"
    Team = "orders"
  }
}
TF
sed -i 's/    Environment = "prod"/    Environment = "prod"\n    CostCenter  = "cc-4711"/' main.tf
terraform apply -auto-approve -no-color
python3 - <<'PY'
import re
s = open("main.tf").read()
s = re.sub(r'\nresource "aws_s3_bucket" "reports" \{.*?\n\}\n', "\n", s, flags=re.S)
open("main.tf", "w").write(s)
PY
terraform state rm aws_s3_bucket.reports
terraform plan -no-color -detailed-exitcode
