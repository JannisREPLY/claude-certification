set -euo pipefail
terraform init -input=false -no-color
terraform apply -auto-approve -input=false -no-color
terraform show -json -no-color | jq -r '.values.root_module.resources[] | select(.address == "random_integer.build") | .values.result' > "$LAB_STATE/build"
aws ec2 describe-security-groups --filters "Name=group-name,Values=web-$(cat "$LAB_STATE/build")" --query 'SecurityGroups[0].GroupId' --output text > "$LAB_STATE/sg"
sed -i 's/version = "~> 5.0"/version = "~> 4.67"/' modules/reports/main.tf
if [ "$LEVEL" = expert ]; then
  python3 - <<'PY'
p = "modules/reports/main.tf"
s = open(p).read()
s = s.replace('''      version = "~> 4.67"
    }
''', '''      version = "~> 4.67"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.0"
    }
''', 1)
open(p, "w").write(s)
PY
fi
