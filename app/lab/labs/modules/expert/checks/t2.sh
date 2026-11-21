source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
for p in orders:s3-read orders:logs-write billing:logs-write billing:s3-read billing:sqs-send; do
  app=${p%%:*} k=${p#*:}
  expect_addresses "module.iam[\"$app\"].aws_iam_policy.access[\"$k\"]" "module.iam[\"$app\"].aws_iam_role_policy_attachment.access[\"$k\"]"
  [ "$(state_attr "module.iam[\"$app\"].aws_iam_policy.access[\"$k\"]" name)" = "$app-$k" ] || fail "module.iam[\"$app\"].aws_iam_policy.access[\"$k\"] is not the policy $app-$k."
done
[ "$(aws iam list-attached-role-policies --role-name billing-app --query 'length(AttachedPolicies)' --output text)" = 3 ] || fail "billing-app should have its three policies attached."
expect_original_resources
pass "The policies and attachments use for_each with stable keys in both applications."
