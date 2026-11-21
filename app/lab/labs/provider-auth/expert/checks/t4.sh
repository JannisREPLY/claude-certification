source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
old=$(cat "$LAB_STATE/key-id")
keys=$(aws iam list-access-keys --user-name terraform-ci --query 'AccessKeyMetadata[].[AccessKeyId,Status]' --output text)
grep -q "^$old" <<< "$keys" && fail "The leaked access key $old still exists in IAM."
new=$(awk '/^\[/ { s = ($0 == "[ci]") } s && $1 == "aws_access_key_id" { print $3 }' /home/coder/secrets/credentials)
grep -qx "$new[[:space:]]*Active" <<< "$keys" || fail "The profile ci uses ${new:-no key}, which is not an active key of terraform-ci."
expect_no_secrets
vars=$(config_json | jq -r '.root_module.variables // {} | keys[] | select(test("access|secret"))' | paste -sd, -)
[ -z "$vars" ] || fail "The configuration still declares credential variables: $vars"
has_address 'module.audit["platform"].aws_iam_role.auditor' || fail "Apply the configuration first."
expect_clean_plan
pass "The leaked key is rotated, no credentials are in the lab folder, and the plan is clean."
