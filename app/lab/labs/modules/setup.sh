set -euo pipefail
source "$LAB_DIR/helpers.sh"
repo=/home/coder/repos/security-group
rm -rf "$repo" && mkdir -p "$repo"
(
  cd "$repo"
  git init -q -b main
  for v in 1.0.0 1.1.0 2.0.0; do
    cp "$LAB_DIR/sg-module/v$v.tf" main.tf
    awk -v v="v$v" '/^- v[0-9]/ { split($2, a, ":"); if (a[1] > v) next } { print }' "$LAB_DIR/sg-module/README.md" > README.md
    git add -A
    git -c user.name=platform -c user.email=platform@example.com commit -qm "Release v$v"
    git tag "v$v"
  done
)
terraform init -input=false -no-color
terraform apply -auto-approve -input=false -no-color
terraform show -json -no-color | fingerprints > "$LAB_STATE/fingerprints"
for app in orders billing; do
  aws ec2 describe-security-groups --filters "Name=group-name,Values=$app-app" --query 'SecurityGroups[0].GroupId' --output text > "$LAB_STATE/sg-$app"
done
