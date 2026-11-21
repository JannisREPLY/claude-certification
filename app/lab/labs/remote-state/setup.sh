set -euo pipefail
aws s3api create-bucket --bucket tfstate-lab > /dev/null
aws dynamodb create-table --table-name tf-locks --billing-mode PAY_PER_REQUEST \
  --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH > /dev/null
cd platform
terraform init -input=false -no-color
terraform apply -auto-approve -input=false -no-color
aws iam get-role --role-name app-runtime-role --query Role.RoleId --output text > "$LAB_STATE/role-id"
aws iam get-instance-profile --instance-profile-name app-runtime-profile --query InstanceProfile.InstanceProfileId --output text > "$LAB_STATE/profile-id"
aws s3api put-object --bucket platform-artifacts --key README.txt --body main.tf > /dev/null
