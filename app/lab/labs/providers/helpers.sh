lock_version() {
  awk -v p="provider \"registry.terraform.io/hashicorp/$1\"" 'index($0, p) == 1 { f = 1 } f && $1 == "version" { gsub(/"/, "", $3); print $3; exit }' .terraform.lock.hcl 2> /dev/null
}

root_tf() { find . -maxdepth 1 -name '*.tf' -print0 | xargs -0 cat; }

expect_init_works() {
  mkdir "$CHECK_TMP/init"
  tar -c --exclude=./.terraform . | tar -x -C "$CHECK_TMP/init"
  local out
  out=$(cd "$CHECK_TMP/init" && terraform init -backend=false -input=false -no-color 2>&1) \
    || fail "terraform init fails:"$'\n'"$(grep -A8 'Error' <<< "$out" | head -n 14)"
  grep -qE 'version += +"~> 5\.0"' <<< "$(root_tf)" || fail "The AWS version constraint of the root module was changed."
  [ "$(lock_version aws)" = 5.100.0 ] || fail "The lock file should still select aws 5.100.0, not $(lock_version aws)."
}

expect_originals() {
  [ "$(state_attr random_integer.build result)" = "$(cat "$LAB_STATE/build")" ] || fail "random_integer.build was recreated."
  [ "$(state_attr aws_security_group.web id)" = "$(cat "$LAB_STATE/sg")" ] || fail "aws_security_group.web was recreated."
}

expect_random_upgraded() {
  [ "$(lock_version random)" = 3.6.3 ] || fail "The lock file selects random $(lock_version random), not 3.6.3."
  grep -qE 'version += +"~> 3\.6\.[0-9]+"' <<< "$(root_tf)" || fail "The root constraint for random must allow only 3.6.x patch releases (~> 3.6.0)."
  expect_originals
}

expect_west_bucket() {
  local addr=$1 loc
  [ "$(state_attr "$addr" bucket)" = acme-reports-west ] || fail "$addr with the bucket acme-reports-west is not in state."
  loc=$(aws s3api get-bucket-location --bucket acme-reports-west --query LocationConstraint --output text 2> /dev/null) || fail "The bucket acme-reports-west does not exist."
  [ "$loc" = us-west-2 ] || fail "acme-reports-west is in $loc, not us-west-2."
  grep -qE 'alias += +"west"' <<< "$(root_tf)" || fail "The root module has no provider configuration with the alias west."
}

expect_module_aliases() {
  tf_has 'configuration_aliases' modules/reports || fail "modules/reports does not declare configuration_aliases."
  tf_has '^\s*provider +"' modules/reports && fail "modules/reports must not contain provider blocks."
  grep -qE '=\s*aws\.west' <<< "$(root_tf | sed -n '/module "reports"/,/^}/p')" || fail "module.reports must get aws.west through the providers meta-argument."
  tf_has 'output +"replica_bucket"' modules/reports || fail "modules/reports has no output replica_bucket."
}

tag_value() {
  case $1 in
    bucket:*) aws s3api get-bucket-tagging --bucket "${1#bucket:}" --query "TagSet[?Key=='$2'].Value | [0]" --output text 2> /dev/null ;;
    sg:*) aws ec2 describe-security-groups --region "${3:-us-east-1}" --group-ids "${1#sg:}" --query "SecurityGroups[0].Tags[?Key=='$2'].Value | [0]" --output text 2> /dev/null ;;
  esac
}

expect_tag() {
  local key=$1 want=$2 target got
  shift 2
  for target in "$@"; do
    got=$(tag_value "${target%@*}" "$key" "$( [[ $target == *@* ]] && echo "${target#*@}")")
    [ "$got" = "$want" ] || fail "${target%@*} has $key = $got in AWS, not $want."
  done
  [ "$(tf_files | grep -c "$key")" -le 2 ] || fail "$key appears more than once per provider configuration; set it with default_tags only."
}
