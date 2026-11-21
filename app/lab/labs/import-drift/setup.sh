set -euo pipefail
terraform init -input=false -no-color
terraform apply -auto-approve -input=false -no-color

ami=$(aws ec2 describe-images --owners amazon --filters 'Name=name,Values=amzn2-ami-hvm-*' --query 'sort_by(Images,&CreationDate)[-1].ImageId' --output text)
vpc=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text)
subnet=$(aws ec2 describe-subnets --filters Name=vpc-id,Values="$vpc" --query 'Subnets[0].SubnetId' --output text)

aws iam create-role --role-name legacy-api-role --assume-role-policy-document \
  '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}' > /dev/null
aws iam create-instance-profile --instance-profile-name legacy-api-profile > /dev/null
aws iam add-role-to-instance-profile --instance-profile-name legacy-api-profile --role-name legacy-api-role
sg=$(aws ec2 create-security-group --group-name legacy-api-sg --description "Legacy API access" --vpc-id "$vpc" --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id "$sg" --protocol tcp --port 443 --cidr 0.0.0.0/0 > /dev/null

run() {
  aws ec2 run-instances --image-id "$ami" --instance-type t3.micro --subnet-id "$subnet" --security-group-ids "$sg" "$@" \
    --query 'Instances[0].InstanceId' --output text
}
run --iam-instance-profile Name=legacy-api-profile \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=legacy-api},{Key=Team,Value=orders}]' > "$LAB_STATE/instance"
if [ "$LEVEL" = expert ]; then
  for w in a b c; do
    run --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=legacy-worker-$w},{Key=Team,Value=orders}]" > "$LAB_STATE/worker-$w"
  done
fi
echo "$sg" > "$LAB_STATE/sg"

aws s3api put-bucket-tagging --bucket orders-artifacts \
  --tagging 'TagSet=[{Key=Team,Value=orders},{Key=Environment,Value=dev},{Key=CostCenter,Value=cc-4711}]'
