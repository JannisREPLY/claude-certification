set -euo pipefail
terraform init -input=false -no-color
terraform apply -auto-approve -input=false -no-color
terraform state show -no-color aws_vpc.main | awk -F'"' '/^ +id +=/{print $2}' > "$LAB_STATE/vpc"
terraform state show -no-color aws_subnet.app | awk -F'"' '/^ +id +=/{print $2}' > "$LAB_STATE/subnet"
