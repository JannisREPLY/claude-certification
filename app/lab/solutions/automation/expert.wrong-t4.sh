set -euo pipefail
cat > ci.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export TF_IN_AUTOMATION=1
export TF_VAR_app_version="$BUILD_VERSION"

terraform init -input=false -backend-config=prod.s3.tfbackend
rc=0
terraform plan -input=false -lock-timeout=2m -detailed-exitcode -out=ci.tfplan || rc=$?
case $rc in
  0) echo "No changes."; exit 0 ;;
  2) ;;
  *) exit 1 ;;
esac
terraform show -json ci.tfplan > ci.tfplan.json
if jq -e '[.resource_changes[]? | select(.change.actions == ["delete"])] | length > 0' ci.tfplan.json > /dev/null; then
  echo "The plan deletes or replaces resources. Manual approval required." >&2
  exit 3
fi
terraform apply -input=false -lock-timeout=2m ci.tfplan
EOF
cat > prod.s3.tfbackend <<'EOF'
bucket         = "payments-tfstate"
key            = "payments/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "payments-tf-locks"
encrypt        = true
EOF
python3 - <<'PY'
import re
s = open("main.tf").read()
s = s.replace('required_version = "~> 1.7.0"', 'required_version = ">= 1.6.0, < 2.0.0"')
s = re.sub(r'backend "s3" \{.*?\n  \}', 'backend "s3" {}', s, flags=re.S)
open("main.tf", "w").write(s)
PY
terraform init -reconfigure -input=false -no-color -backend-config=prod.s3.tfbackend
terraform force-unlock -force 9b2f6c1e-4d8a-4f3b-a7c5-2e1d0f9a8b76
BUILD_VERSION=1.4.0 bash ci.sh < /dev/null
TF_VAR_app_version=1.4.0 terraform plan -detailed-exitcode -input=false -no-color
