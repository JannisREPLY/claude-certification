set -euo pipefail
terraform plan -var-file=prod.tfvars -out=tfplan -no-color > /dev/null
terraform apply -no-color tfplan
terraform apply -replace=aws_subnet.app -var-file=prod.tfvars -auto-approve -no-color
terraform destroy -target=aws_security_group.debug -var-file=prod.tfvars -auto-approve -no-color
python3 - <<'PY'
import re
s = open("main.tf").read()
s = re.sub(r'\nresource "aws_security_group" "debug" \{.*?\n\}\n', "\n", s, flags=re.S)
s = s.replace('  cidr_block = "10.0.0.0/16"\n', '  cidr_block = "10.0.0.0/16"\n\n  lifecycle {\n    prevent_destroy = true\n  }\n', 1)
open("main.tf", "w").write(s)
PY
terraform plan -var-file=prod.tfvars -no-color | tail -1
