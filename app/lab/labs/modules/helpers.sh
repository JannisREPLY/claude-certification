fingerprints() {
  jq -r '[.values.root_module? // {} | .. | objects | select(.mode? == "managed") | "\(.type) \(if .type == "aws_autoscaling_group" then .values.arn else (.values.policy_id // .values.unique_id // .values.id) end)"] | sort | .[]'
}

expect_original_resources() {
  local gone
  gone=$(comm -23 "$LAB_STATE/fingerprints" <(state_json | fingerprints) | cut -d' ' -f1 | uniq -c | awk '{printf "%s%s x%s", (NR > 1 ? ", " : ""), $2, $1}')
  [ -z "$gone" ] || fail "Resources were destroyed or recreated since the lab started: $gone"
}

module_source() {
  jq -r --arg k "$1" '.Modules[]? | select(.Key == $k) | .Source' .terraform/modules/modules.json 2> /dev/null
}

module_resource() {
  ensure_plan
  config_json | jq --arg m "$1" --arg a "$2" '[.root_module.module_calls[$m].module.resources[]? | select(.address == $a)] | first // empty'
}

expect_ref() {
  ensure_plan
  config_json | jq -e --arg m "$1" --arg i "$2" --arg p "$3" '.root_module.module_calls[$m].expressions[$i].references // [] | any(startswith($p))' > /dev/null \
    || fail "The input $2 of module.$1 must reference $3 instead of a hard-coded value."
}

expect_addresses() {
  local a
  for a in "$@"; do has_address "$a" || fail "$a is not in state. Did you run terraform apply?"; done
}

expect_no_old_module() {
  local old
  old=$(addresses | grep '^module\.app[.[]' | paste -sd, -) || true
  [ -z "$old" ] || fail "module.app still has resources in state: $old"
}

expect_sg_module() {
  local src
  src=$(module_source app_sg)
  [ -n "$src" ] || fail "module.app_sg is not installed. Did you run terraform init?"
  [[ "$src" == git::file:///home/coder/repos/security-group* ]] || fail "module.app_sg comes from $src, not the platform Git repository."
  [[ "$src" == *"ref=v1.1.0"* ]] || fail "module.app_sg is not pinned to the right tag (source: $src)."
}

expect_sg() {
  local app=$1 prefix=$2 want rules
  want=$(cat "$LAB_STATE/sg-$app")
  [ "$(state_attr "$prefix.aws_security_group.this" id)" = "$want" ] || fail "$prefix.aws_security_group.this is not the original security group $want."
  [ -n "$(state_attr "$prefix.aws_vpc_security_group_ingress_rule.this[\"https\"]" id)" ] || fail "$prefix.aws_vpc_security_group_ingress_rule.this[\"https\"] is not in state."
  rules=$(aws ec2 describe-security-group-rules --filters "Name=group-id,Values=$want" --query 'SecurityGroupRules[?!IsEgress && FromPort==`443`] | length(@)' --output text)
  [ "$rules" = 1 ] || fail "The HTTPS rule of $app-app is gone."
  [ "$(aws ec2 describe-security-groups --group-ids "$want" --query 'SecurityGroups[0].Description' --output text)" = "$app app instances" ] || fail "The description of $app-app changed."
  grep -qxF "$want" <<< "$(aws ec2 describe-launch-template-versions --launch-template-name "$app-app" --versions '$Latest' --query 'LaunchTemplateVersions[0].LaunchTemplateData.SecurityGroupIds[]' --output text | tr '\t' '\n')" \
    || fail "The launch template $app-app no longer uses the security group $want."
}
