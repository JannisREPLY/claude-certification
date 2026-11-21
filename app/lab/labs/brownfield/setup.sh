set -euo pipefail
terraform init -input=false -no-color
terraform apply -auto-approve -input=false -no-color

aws s3api create-bucket --bucket nw-bf-tfstate > /dev/null
aws dynamodb create-table --table-name nw-bf-tf-locks --billing-mode PAY_PER_REQUEST \
  --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH > /dev/null
aws s3api put-object --bucket nw-bf-manifests --key README.txt --body main.tf > /dev/null

ami=$(aws ec2 describe-images --owners amazon --filters 'Name=name,Values=amzn2-ami-hvm-*' --query 'sort_by(Images,&CreationDate)[-1].ImageId' --output text)
vpc=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text)
subnet=$(aws ec2 describe-subnets --filters Name=vpc-id,Values="$vpc" --query 'sort_by(Subnets,&SubnetId)[0].SubnetId' --output text)

aws iam create-role --role-name nw-bf-web-role --assume-role-policy-document \
  '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}' \
  --query Role.RoleId --output text > "$LAB_STATE/role-id"
aws iam create-instance-profile --instance-profile-name nw-bf-web-profile \
  --query InstanceProfile.InstanceProfileId --output text > "$LAB_STATE/profile-id"
aws iam add-role-to-instance-profile --instance-profile-name nw-bf-web-profile --role-name nw-bf-web-role
sg=$(aws ec2 create-security-group --group-name nw-bf-web-sg --description "Dispatch web access" --vpc-id "$vpc" --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id "$sg" --protocol tcp --port 443 --cidr 0.0.0.0/0 > /dev/null
echo "$sg" > "$LAB_STATE/sg"

for n in 1 2; do
  aws ec2 run-instances --image-id "$ami" --instance-type t3.micro --subnet-id "$subnet" --security-group-ids "$sg" \
    --iam-instance-profile Name=nw-bf-web-profile \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=nw-bf-web-$n},{Key=Team,Value=dispatch}]" \
    --query 'Instances[0].InstanceId' --output text > "$LAB_STATE/web-$n"
done

tracker=$(aws ec2 describe-security-groups --filters Name=group-name,Values=nw-bf-tracker-sg Name=vpc-id,Values="$vpc" --query 'SecurityGroups[0].GroupId' --output text)
echo "$tracker" > "$LAB_STATE/tracker"
aws ec2 authorize-security-group-ingress --group-id "$tracker" --protocol tcp --port 22 --cidr 0.0.0.0/0 > /dev/null
aws ec2 create-tags --resources "$tracker" --tags Key=Owner,Value=dispatch-oncall
