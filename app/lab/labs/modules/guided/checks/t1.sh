source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
expect_addresses module.iam.aws_iam_role.this module.iam.aws_iam_instance_profile.this \
  'module.iam.aws_iam_policy.access[0]' 'module.iam.aws_iam_policy.access[1]' \
  'module.iam.aws_iam_role_policy_attachment.access[0]' 'module.iam.aws_iam_role_policy_attachment.access[1]'
tf_has 'output +"instance_profile_name"' modules/iam || fail "modules/iam has no output instance_profile_name."
expect_original_resources
expect_nothing_destroyed
pass "The IAM resources live in module.iam and kept their IDs."
