set -euo pipefail
terraform init -input=false -no-color
terraform apply -auto-approve -input=false -no-color
terraform state show -no-color random_pet.suffix | awk -F'"' '/^ +id +=/{print $2}' > "$LAB_STATE/pet"
sed -i 's/version = "~> 5.0"/version = "~> 4.67"/' modules/logs/main.tf
rm -rf .terraform/modules
