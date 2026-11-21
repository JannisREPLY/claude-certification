set -euo pipefail
terraform init -upgrade -input=false -no-color
terraform plan -var-file=prod.tfvars -out=prod.tfplan -input=false -no-color
terraform apply -input=false -no-color prod.tfplan
python3 - <<'PY'
import re
s = open("main.tf").read()
s = re.sub(r'\nresource "aws_(security_group|instance)" "debug" \{.*?\n\}\n', "\n", s, flags=re.S)
open("main.tf", "w").write(s)
PY
terraform apply -auto-approve -input=false -no-color
