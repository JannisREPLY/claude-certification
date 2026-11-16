set -euo pipefail
vpc=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=legacy-vpc --query "Vpcs[0].VpcId" --output text)
sg=$(aws ec2 describe-security-groups --filters Name=group-name,Values=legacy-web --query "SecurityGroups[0].GroupId" --output text)
cat > imports.tf <<HCL
import {
  to = aws_vpc.legacy
  id = "$vpc"
}

import {
  to = aws_security_group.legacy_web
  id = "$sg"
}
HCL
terraform plan -generate-config-out=generated.tf -no-color > /dev/null 2>&1 || true
sed -i "/ipv6_netmask_length/d" generated.tf
sed -i 's/Name = "app-subnet"/Name  = "app-subnet"\n    Owner = "platform"/' main.tf
terraform apply -auto-approve -no-color
