set -euo pipefail
repo=/home/coder/repos/web-sg
rm -rf /home/coder/repos && mkdir -p "$repo" && cd "$repo"
git init -q -b main
for v in v1.0.0 v1.1.0; do
  cp "$LAB_DIR/web-sg/$v.tf" main.tf
  printf '# web-sg\n\nSecurity group module. Inputs: name, vpc_id%s. Output: id.\n' "$([ $v = v1.1.0 ] && echo ', description')" > README.md
  git add -A && git -c user.name=platform -c user.email=platform@example.com commit -qm "$v" && git tag "$v"
done
cd /home/coder/lab
terraform init -input=false -no-color
terraform apply -auto-approve -input=false -no-color
for a in aws_vpc.main 'aws_subnet.public[0]' 'aws_subnet.public[1]' aws_security_group.web; do
  terraform state show -no-color "$a" | awk -F'"' '/^ +id +=/{print $2}'
done > "$LAB_STATE/ids"
