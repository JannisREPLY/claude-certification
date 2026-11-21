source "$LIB"
require_init
for r in aws_iam_policy.read aws_iam_role.reader aws_iam_role_policy_attachment.reader; do
  has_address "module.access.$r" || fail "module.access.$r is not in state."
done
grep -q '^module\.platform\.' <<< "$(addresses)" && fail "There are still resources under module.platform in state."
[ "$(grep -c '^module\.storage\.aws_s3_bucket\.this\[' <<< "$(addresses)")" = 3 ] || fail "module.storage should manage the three buckets as aws_s3_bucket.this."
[ -d modules/platform ] && fail "The folder modules/platform still exists."
cfg=$(config_json)
[ "$(jq -r '.root_module.module_calls.platform // empty | length' <<< "$cfg")" = "" ] || fail "module.platform is still called."
[ "$(jq -r '.root_module.module_calls.storage.source // empty' <<< "$cfg")" = ./modules/storage ] || fail "module.storage must use the source ./modules/storage."
[ "$(jq -r '.root_module.module_calls.access.source // empty' <<< "$cfg")" = ./modules/access ] || fail "module.access must use the source ./modules/access."
jq -e '.root_module.module_calls.storage.module.outputs.bucket_arns' <<< "$cfg" > /dev/null || fail "module.storage has no output bucket_arns."
jq -e '.root_module.module_calls.access.module.variables.bucket_arns' <<< "$cfg" > /dev/null || fail "module.access has no input variable bucket_arns."
jq -e '.root_module.module_calls.access.expressions.bucket_arns.references // [] | index("module.storage.bucket_arns")' <<< "$cfg" > /dev/null \
  || fail "The input bucket_arns of module.access must reference module.storage.bucket_arns."
arn=$(aws iam get-role --role-name nw-sto-reader --query Role.Arn --output text)
[ "$(state_json | jq -r '.values.outputs.reader_role_arn.value // empty')" = "$arn" ] || fail "The output reader_role_arn should be $arn."
pass "module.platform is split into module.storage and module.access."
