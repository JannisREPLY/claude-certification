set -euo pipefail
terraform init -input=false -no-color
terraform apply -auto-approve -input=false -no-color

legacy=$(aws ec2 create-vpc --cidr-block 10.1.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=legacy-vpc},{Key=Team,Value=web}]' \
  --query Vpc.VpcId --output text)
sg=$(aws ec2 create-security-group --group-name legacy-web --description "Legacy web access" --vpc-id "$legacy" \
  --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id "$sg" --protocol tcp --port 443 --cidr 0.0.0.0/0 > /dev/null

app=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=app-vpc --query 'Vpcs[0].VpcId' --output text)
subnet=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=app-subnet --query 'Subnets[0].SubnetId' --output text)
aws ec2 create-tags --resources "$app" --tags Key=Environment,Value=prod
aws ec2 create-tags --resources "$subnet" --tags Key=Owner,Value=platform
