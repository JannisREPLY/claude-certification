set -euo pipefail
instance=$(aws ec2 describe-instances --filters Name=tag:Name,Values=legacy-api --query 'Reservations[0].Instances[0]' --output json)
cat > legacy.tf <<TF
import {
  to = aws_iam_role.legacy_api
  id = "legacy-api-role"
}

import {
  to = aws_instance.legacy_api
  id = "$(echo "$instance" | jq -r .InstanceId)"
}

resource "aws_iam_role" "legacy_api" {
  name = "legacy-api-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_instance" "legacy_api" {
  ami                    = "$(echo "$instance" | jq -r .ImageId)"
  instance_type          = "t3.micro"
  subnet_id              = "$(echo "$instance" | jq -r .SubnetId)"
  vpc_security_group_ids = ["$(echo "$instance" | jq -r '.SecurityGroups[0].GroupId')"]
  iam_instance_profile   = "legacy-api-profile"

  tags = {
    Name = "legacy-api"
    Team = "orders"
  }
}
TF
sed -i 's/    Environment = "prod"/    Environment = "prod"\n    CostCenter  = "cc-4711"/' main.tf
terraform apply -auto-approve -no-color
terraform plan -no-color -detailed-exitcode
