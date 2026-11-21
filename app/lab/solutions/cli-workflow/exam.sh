set -euo pipefail
terraform init -upgrade -input=false -no-color
terraform plan -var-file=prod.tfvars -out=prod.tfplan -input=false -no-color
terraform apply -input=false -no-color prod.tfplan
terraform apply -replace='aws_instance.web[1]' -var-file=prod.tfvars -auto-approve -input=false -no-color
terraform destroy -target=aws_instance.debug -target=aws_security_group.debug -var-file=prod.tfvars -auto-approve -input=false -no-color
python3 - <<'PY'
import re
s = open("main.tf").read()
s = re.sub(r'\nresource "aws_(security_group|instance)" "debug" \{.*?\n\}\n', "\n", s, flags=re.S)
s = s.replace("    ignore_changes = [tags]\n", "    ignore_changes  = [tags]\n    prevent_destroy = true\n")
open("main.tf", "w").write(s)
PY
terraform apply -refresh-only -var-file=prod.tfvars -auto-approve -input=false -no-color
terraform plan -var-file=prod.tfvars -detailed-exitcode -input=false -no-color
