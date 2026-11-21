set -euo pipefail
cat > ci.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export TF_IN_AUTOMATION=1
export TF_VAR_app_version="$BUILD_VERSION"

terraform init -input=false
rc=0
terraform plan -input=false -detailed-exitcode -out=ci.tfplan || rc=$?
case $rc in
  0) echo "No changes." ;;
  2) terraform apply -input=false ci.tfplan ;;
  *) exit 1 ;;
esac
EOF
sed -i '/key    = "payments\/terraform.tfstate"/a\    dynamodb_table = "payments-tf-locks"' main.tf
terraform init -reconfigure -input=false -no-color
BUILD_VERSION=1.3.0 bash ci.sh < /dev/null
TF_VAR_app_version=1.3.0 terraform plan -detailed-exitcode -input=false -no-color
