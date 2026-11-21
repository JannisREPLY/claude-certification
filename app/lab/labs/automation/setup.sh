set -euo pipefail
aws s3api create-bucket --bucket payments-tfstate > /dev/null
aws dynamodb create-table --table-name payments-tf-locks --billing-mode PAY_PER_REQUEST \
  --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH > /dev/null
terraform init -input=false -no-color
TF_VAR_app_version=1.0.0 terraform apply -auto-approve -input=false -no-color
aws s3 cp s3://payments-tfstate/payments/terraform.tfstate - | jq -r .lineage > "$LAB_STATE/lineage"
if [ "$LEVEL" = expert ]; then
  sed -i 's/required_version = ">= 1.6.0"/required_version = "~> 1.7.0"/' main.tf
  echo 9b2f6c1e-4d8a-4f3b-a7c5-2e1d0f9a8b76 > "$LAB_STATE/stale-lock"
  info=$(jq -cn --arg id "$(cat "$LAB_STATE/stale-lock")" '{ID: $id, Operation: "OperationTypeApply", Info: "", Who: "runner@ci-runner-17", Version: "1.6.6", Created: "2026-11-19T22:14:03.512Z", Path: "payments-tfstate/payments/terraform.tfstate"}')
  aws dynamodb put-item --table-name payments-tf-locks --item "$(jq -cn --arg info "$info" '{LockID: {S: "payments-tfstate/payments/terraform.tfstate"}, Info: {S: $info}}')"
fi
