source "$LIB"
require_init
tf_has '^\s*moved\s*\{' || fail "No moved block found."
[ "$(aws iam get-role --role-name nw-sto-reader --query Role.RoleId --output text 2> /dev/null)" = "$(cat "$LAB_STATE/role-id")" ] \
  || fail "The role nw-sto-reader was recreated or deleted."
[ "$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='nw-sto-read'].PolicyId | [0]" --output text)" = "$(cat "$LAB_STATE/policy-id")" ] \
  || fail "The policy nw-sto-read was recreated or deleted."
grep -qx nw-sto-read <<< "$(aws iam list-attached-role-policies --role-name nw-sto-reader --query 'AttachedPolicies[].PolicyName' --output text | tr '\t' '\n')" \
  || fail "nw-sto-read is no longer attached to nw-sto-reader."
for b in nw-sto-manifests nw-sto-invoices nw-sto-archive; do
  [ "$(aws s3api list-buckets --query "Buckets[?Name=='$b'].CreationDate | [0]" --output text)" = "$(cat "$LAB_STATE/created-$b")" ] \
    || fail "The bucket $b was recreated or deleted."
  aws s3api head-object --bucket "$b" --key data/2026-11-01.csv > /dev/null 2>&1 || fail "The application data in $b is gone."
  aws s3api head-object --bucket "$b" --key README.txt > /dev/null 2>&1 || fail "README.txt in $b is gone."
done
expect_clean_plan
pass "Nothing was destroyed or recreated, and the plan is clean."
