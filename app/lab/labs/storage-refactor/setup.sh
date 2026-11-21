set -euo pipefail
repo=/home/coder/git/nw-sto-tagging.git
src=$(mktemp -d)
rm -rf "$repo"
mkdir -p "$(dirname "$repo")"
g() { git -C "$src" -c user.name=platform -c user.email=platform@northwind.example "$@"; }
release() {
  g add -A
  g commit -qm "$1"
  g tag "$1"
}
g init -q -b main

cat > "$src/versions.tf" <<'TF'
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}
TF
cat > "$src/main.tf" <<'TF'
variable "team" {
  type = string
}

output "tags" {
  value = {
    Team      = var.team
    Company   = "Northwind Logistics"
    ManagedBy = "terraform"
  }
}
TF
release v1.0.0

cat > "$src/main.tf" <<'TF'
variable "team" {
  type = string
}

variable "environment" {
  type    = string
  default = "prod"
}

output "tags" {
  value = {
    Team        = var.team
    Company     = "Northwind Logistics"
    ManagedBy   = "terraform"
    Environment = var.environment
  }
}
TF
release v1.1.0

cat > "$src/main.tf" <<'TF'
variable "team" {
  type = string
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "data_class" {
  type    = string
  default = "internal"
}

output "tags" {
  value = {
    Team        = var.team
    Company     = "Northwind Logistics"
    ManagedBy   = "terraform"
    Environment = var.environment
    DataClass   = var.data_class
  }
}
TF
release v1.2.0

sed -i 's/">= 5.0"/">= 6.0"/' "$src/versions.tf"
sed -i 's/^output "tags"/output "labels"/' "$src/main.tf"
release v2.0.0

git clone -q --bare "$src" "$repo"
rm -rf "$src"

terraform init -input=false -no-color
terraform apply -auto-approve -input=false -no-color

data=$(mktemp)
for b in nw-sto-manifests nw-sto-invoices nw-sto-archive; do
  echo "shipment,date" > "$data"
  aws s3api put-object --bucket "$b" --key "data/2026-11-01.csv" --body "$data" > /dev/null
  aws s3api list-buckets --query "Buckets[?Name=='$b'].CreationDate | [0]" --output text > "$LAB_STATE/created-$b"
done
rm -f "$data"
aws iam get-role --role-name nw-sto-reader --query Role.RoleId --output text > "$LAB_STATE/role-id"
aws iam list-policies --scope Local --query "Policies[?PolicyName=='nw-sto-read'].PolicyId | [0]" --output text > "$LAB_STATE/policy-id"
