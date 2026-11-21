source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
for k in s3-read logs-write; do
  expect_addresses "module.iam.aws_iam_policy.access[\"$k\"]" "module.iam.aws_iam_role_policy_attachment.access[\"$k\"]"
  [ "$(state_attr "module.iam.aws_iam_policy.access[\"$k\"]" name)" = "orders-$k" ] || fail "module.iam.aws_iam_policy.access[\"$k\"] is not the policy orders-$k."
done
[ "$(aws iam list-attached-role-policies --role-name orders-app --query 'length(AttachedPolicies)' --output text)" = 2 ] || fail "orders-app should have its two policies attached."
expect_original_resources
pass "The policies and attachments use for_each with stable keys."
