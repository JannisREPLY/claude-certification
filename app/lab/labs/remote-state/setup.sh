set -euo pipefail
aws s3api create-bucket --bucket tfstate-lab > /dev/null
aws dynamodb create-table --table-name tf-locks --billing-mode PAY_PER_REQUEST \
  --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH > /dev/null
cd network
terraform init -input=false -no-color
terraform apply -auto-approve -input=false -no-color
terraform output -raw vpc_id > "$LAB_STATE/vpc"
