set -euo pipefail
cp main.tf "$LAB_STATE/main.tf.orig"
cat > main.tf <<'TF'
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
TF
terraform init -input=false -no-color
mv "$LAB_STATE/main.tf.orig" main.tf
md5sum rules.yaml terraform.tfvars $(ls partner-rules.csv 2> /dev/null) > "$LAB_STATE/inputs.md5"
