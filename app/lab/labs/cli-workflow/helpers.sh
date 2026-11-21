source "$LIB"
require_init

id_was() { jq -r --arg a "$1" '.[$a] // empty' "$LAB_STATE/ids.json"; }

web_addresses() { jq -r 'keys[] | select(startswith("aws_instance.web["))' "$LAB_STATE/ids.json"; }

expect_kept() {
  [ "$(state_attr "$1" id)" = "$(id_was "$1")" ] || fail "$1 was replaced or removed (ID changed)."
}

expect_web_env() {
  local a id env
  for a in $(web_addresses); do
    id=$(state_attr "$a" id)
    [ -n "$id" ] || fail "$a is missing from state."
    env=$(aws ec2 describe-instances --instance-ids "$id" --query "Reservations[0].Instances[0].Tags[?Key=='Environment'].Value | [0]" --output text 2> /dev/null) || fail "Instance $id of $a does not exist in AWS."
    [ "$env" = "$1" ] || fail "$a has Environment = $env in AWS, expected $1."
  done
}

check_lock_fix() {
  local v
  v=$(awk '/provider "registry.terraform.io\/hashicorp\/random"/{f=1} f && /version/{gsub(/"/,"",$3); print $3; exit}' .terraform.lock.hcl)
  [ "$v" = 3.6.3 ] || fail "The lock file pins random ${v:-?}, not the newest 3.6.x release."
  tf_has 'version += "~> 3\.6\.0"' || fail "The version constraint of random was changed."
  expect_kept random_integer.build
}

check_saved_plan() {
  local pj lineage serial
  [ -f prod.tfplan ] || fail "No saved plan prod.tfplan in the lab folder."
  pj=$(terraform show -json -no-color prod.tfplan 2> "$CHECK_TMP/show.log") || fail "prod.tfplan is not a valid saved plan:"$'\n'"$(tail -n 5 "$CHECK_TMP/show.log")"
  [ "$(jq -r '.variables.environment.value' <<< "$pj")" = prod ] || fail "prod.tfplan was not created with the values from prod.tfvars."
  for a in $(web_addresses); do
    [ "$(jq -r --arg a "$a" '[.resource_changes[] | select(.address == $a) | .change.actions | join(",")] | first // "absent"' <<< "$pj")" = update ] \
      || fail "prod.tfplan does not update $a in place."
  done
  read -r lineage serial <<< "$(unzip -p prod.tfplan tfstate | jq -r '"\(.lineage) \(.serial)"')"
  [ "$lineage" = "$(jq -r .lineage terraform.tfstate)" ] || fail "prod.tfplan belongs to a different state."
  [ "$serial" -ge "$(jq -r .serial "$LAB_STATE/state.json")" ] || fail "prod.tfplan is older than the lab."
  [ "$(jq -r .serial terraform.tfstate)" -gt "$serial" ] || fail "prod.tfplan has not been applied yet."
}

check_replaced() {
  local a=$1 id
  id=$(state_attr "$a" id)
  [ -n "$id" ] || fail "$a is missing from state."
  [ "$id" != "$(id_was "$a")" ] || fail "$a still has its original ID $id; it was not replaced."
  [ "$(aws ec2 describe-instances --instance-ids "$id" --query 'Reservations[0].Instances[0].State.Name' --output text)" = running ] || fail "Instance $id is not running."
  for b in $(web_addresses) aws_security_group.web aws_s3_bucket.artifacts random_integer.build; do
    [ "$b" = "$a" ] || expect_kept "$b"
  done
  tf_has 'replace_triggered_by' && fail "Replace the instance with a CLI option, not by editing files."
  expect_web_env prod
}

check_debug_gone() {
  local n
  n=$(aws ec2 describe-instances --filters Name=tag:Name,Values=storefront-debug Name=instance-state-name,Values=pending,running,stopping,stopped --query 'length(Reservations[].Instances[])' --output text)
  [ "$n" = 0 ] || fail "The instance storefront-debug still exists in AWS."
  n=$(aws ec2 describe-security-groups --filters Name=group-name,Values=storefront-debug --query 'length(SecurityGroups)' --output text)
  [ "$n" = 0 ] || fail "The security group storefront-debug still exists in AWS."
  has_address aws_instance.debug && fail "aws_instance.debug is still in state."
  has_address aws_security_group.debug && fail "aws_security_group.debug is still in state."
  tf_has '"debug"' && fail "The debug resources are still in the configuration."
  for b in aws_security_group.web aws_s3_bucket.artifacts random_integer.build; do expect_kept "$b"; done
  for b in $(web_addresses); do has_address "$b" || fail "$b is missing from state."; done
  expect_web_env prod
}

prod_plan() {
  local rc=0
  terraform plan -var-file=prod.tfvars -detailed-exitcode -lock=false -input=false -no-color > "$CHECK_TMP/prod.log" 2>&1 || rc=$?
  case $rc in
    0) ;;
    2) fail "terraform plan -var-file=prod.tfvars still has changes:"$'\n'"$(grep -E '^  # ' "$CHECK_TMP/prod.log")" ;;
    *) fail "terraform plan -var-file=prod.tfvars fails:"$'\n'"$(tail -n 15 "$CHECK_TMP/prod.log")" ;;
  esac
}

expect_protected() {
  local out
  out=$(terraform plan -destroy -var-file=prod.tfvars -lock=false -input=false -no-color 2>&1) && fail "terraform plan -destroy succeeds; nothing is protected."
  grep -q "Instance cannot be destroyed" <<< "$out" || fail "terraform plan -destroy fails for another reason:"$'\n'"$(tail -n 12 <<< "$out")"
  out=$(tr -s ' \n' ' ' <<< "$out")
  for a in "$@"; do
    grep -qF "Resource $a has lifecycle.prevent_destroy set" <<< "$out" || fail "$a is not protected with prevent_destroy."
  done
}

check_output_synced() {
  local tags
  tags=$(aws s3api get-bucket-tagging --bucket storefront-artifacts --query TagSet --output json)
  [ "$(jq -r '.[] | select(.Key=="CostCenter") | .Value' <<< "$tags")" = cc-2201 ] || fail "The CostCenter tag was removed from storefront-artifacts in AWS."
  [ "$(jq -r '.[] | select(.Key=="Team") | .Value' <<< "$tags")" = storefront ] || fail "The Team tag of storefront-artifacts changed in AWS."
  tf_has 'cc-2201' && fail "Don't add the FinOps tags to the configuration."
  tf_has 'ignore_changes += \[tags\]' || fail "The bucket must keep ignoring tag changes."
  [ "$(terraform output -json artifacts_tags 2> /dev/null | jq -r '.CostCenter // empty')" = cc-2201 ] || fail "terraform output artifacts_tags does not show CostCenter = cc-2201."
}
