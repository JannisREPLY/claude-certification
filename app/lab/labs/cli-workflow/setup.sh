set -euo pipefail
terraform init -input=false -no-color
terraform apply -auto-approve -input=false -no-color
terraform show -json -no-color | jq '[.values.root_module.resources[] | select(.mode == "managed") | {key: .address, value: .values.id}] | from_entries' > "$LAB_STATE/ids.json"
jq '{serial, lineage}' terraform.tfstate > "$LAB_STATE/state.json"
aws s3api put-bucket-tagging --bucket storefront-artifacts --tagging 'TagSet=[{Key=Team,Value=storefront},{Key=CostCenter,Value=cc-2201}]'
sed -i 's/version = "3.1.0"/version = "~> 3.6.0"/' main.tf
