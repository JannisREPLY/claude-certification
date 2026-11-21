set -euo pipefail
sed -i 's/version = "~> 3.6.0"/version = "3.1.0"/' main.tf
terraform plan -var-file=prod.tfvars -out=prod.tfplan -input=false -no-color
terraform apply -input=false -no-color prod.tfplan
