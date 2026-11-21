set -euo pipefail
sed -i 's/~> 4.67/>= 5.0/' modules/backup/versions.tf
terraform init -input=false -no-color
terraform apply -auto-approve -input=false -no-color
sed -i 's/>= 5.0/~> 4.67/' modules/backup/versions.tf
cat > .terraform.lock.hcl <<'HCL'
# This file is maintained automatically by "terraform init".
# Manual edits may be lost in future updates.

provider "registry.terraform.io/hashicorp/aws" {
  version     = "5.31.0"
  constraints = "~> 5.0"
  hashes = [
    "h1:WwgMbMOhZblxZTdjHeJf9XB2/hcSHHmpuywLxuTWYw0=",
    "zh:0cdb9c2083bf0902442384f7309367791e4640581652dda456f2d6d7abf0de8d",
  ]
}
HCL
aws s3api put-object --bucket nw-dr-primary-data --key README.txt --body main.tf > /dev/null
vpc=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text)
aws ec2 describe-security-groups --filters Name=group-name,Values=nw-dr-app-sg Name=vpc-id,Values="$vpc" --query 'SecurityGroups[0].GroupId' --output text > "$LAB_STATE/sg-id"
