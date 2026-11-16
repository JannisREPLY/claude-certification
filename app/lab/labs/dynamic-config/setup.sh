set -euo pipefail
aws ec2 create-vpc --cidr-block 10.50.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=shared-vpc}]' --query Vpc.VpcId --output text > "$LAB_STATE/vpc"
terraform init -input=false -no-color
