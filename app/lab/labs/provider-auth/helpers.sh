ACCOUNT=123456789012

output_value() { state_json | jq -c --arg o "$1" '.values.outputs[$o].value // empty' | sed 's/^"\(.*\)"$/\1/'; }

expect_provider_auth() {
  ensure_plan
  local key=$1 cfg
  cfg=$(config_json | jq -c --arg k "$key" '.provider_config[$k] // empty')
  [ -n "$cfg" ] || fail "There is no provider configuration $key."
  jq -e '.expressions.access_key // .expressions.secret_key // .expressions.token' <<< "$cfg" > /dev/null && fail "The provider $key must not set access_key, secret_key or token."
  jq -e '.expressions.profile' <<< "$cfg" > /dev/null || fail "The provider $key does not set profile."
  jq -e '.expressions.profile.constant_value // "ci" | . == "ci"' <<< "$cfg" > /dev/null || fail "The provider $key must use the profile ci."
  jq -e '.expressions.shared_credentials_files' <<< "$cfg" > /dev/null || fail "The provider $key does not set shared_credentials_files."
  [ "${2:-}" = profile-only ] || jq -e '.expressions.assume_role[0].role_arn' <<< "$cfg" > /dev/null || fail "The provider $key has no assume_role block with role_arn."
}

expect_no_secrets() {
  local id secret hits
  id=$(cat "$LAB_STATE/key-id")
  secret=$(cat "$LAB_STATE/secret")
  hits=$(grep -rlF -e "$id" -e "$secret" --exclude-dir=.terraform . 2> /dev/null | paste -sd, -) || true
  [ -z "$hits" ] || fail "The access key of terraform-ci appears in: $hits"
  hits=$(find . -path ./.terraform -prune -o -type f \( -name '*.tf' -o -name '*.tfvars' -o -name '*.tfvars.json' \) -print0 | xargs -0 grep -lE '(access_key|secret_key|AKIA[0-9A-Z]{12,})' 2> /dev/null | paste -sd, -) || true
  [ -z "$hits" ] || fail "Credentials or credential arguments in: $hits"
}

expect_output_ref() {
  ensure_plan
  config_json | jq -e --arg o "$1" --arg p "$2" '.root_module.outputs[$o].expression.references // [] | any(startswith($p))' > /dev/null \
    || fail "The output $1 must come from $2."
}

expect_module_fixed() {
  tf_has '^\s*provider +"' modules/audit && fail "modules/audit still contains a provider block."
  tf_has 'required_providers' modules/audit && tf_has '"hashicorp/aws"' modules/audit || fail "modules/audit does not declare hashicorp/aws in required_providers."
  ensure_plan
  local team
  for team in platform data; do
    has_address "module.audit[\"$team\"].aws_iam_role.auditor" || fail "module.audit[\"$team\"].aws_iam_role.auditor is not in state. Did you apply?"
    aws iam get-role --role-name "$team-auditor" > /dev/null 2>&1 || fail "The role $team-auditor does not exist."
  done
}

expect_deployers() {
  local want=$1 got
  got=$(state_json | jq -c '.values.outputs.deployers.value // empty')
  [ -n "$got" ] || fail "There is no root output deployers. Did you apply?"
  [ "$got" = "$(jq -cn --arg w "$want" '{data: $w, platform: $w}')" ] || fail "deployers is $got; both teams should show $want."
}

config_tree() { sed -e '/^Providers required by state/,$d' -e 's/[[:space:]]*$//' | grep -v '^$'; }

expect_providers_txt() {
  [ -f providers.txt ] || fail "providers.txt is missing."
  local want
  want=$(terraform providers -no-color 2>&1)
  [ "$(config_tree < providers.txt)" = "$(config_tree <<< "$want")" ] \
    || fail "providers.txt doesn't match the current output of terraform providers."
}

expect_version_txt() {
  [ -f version.txt ] || fail "version.txt is missing."
  grep -q '^Terraform v1\.6\.6' version.txt && grep -q '^on linux_' version.txt || fail "version.txt is not the output of terraform version."
  grep -q 'provider registry.terraform.io/hashicorp/aws v5\.100\.0' version.txt || fail "version.txt doesn't list the AWS provider. Run terraform version in the initialized lab folder."
}

expect_plugin_path() {
  [ -f plugin-path.txt ] || fail "plugin-path.txt is missing."
  local p v
  p=$(head -n 1 plugin-path.txt | tr -d '[:space:]')
  p=${p#./}
  v=$(awk '/provider "registry.terraform.io\/hashicorp\/aws"/ { f = 1 } f && $1 == "version" { gsub(/"/, "", $3); print $3; exit }' .terraform.lock.hcl)
  [[ "$p" =~ ^\.terraform/providers/registry\.terraform\.io/hashicorp/aws/${v//./\\.}/linux_(amd64|arm64)/terraform-provider-aws_v${v//./\\.}_x5$ ]] \
    || fail "plugin-path.txt should hold the path of the AWS $v plugin executable below .terraform/providers/, relative to the lab folder (got: $p)."
  [ -x "$p" ] || fail "$p is not an executable file."
}
