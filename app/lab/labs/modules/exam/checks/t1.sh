source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
expect_addresses module.iam.aws_iam_role.this module.iam.aws_iam_instance_profile.this \
  module.compute.aws_launch_template.this module.compute.aws_autoscaling_group.this
expect_no_old_module
[ ! -e modules/app ] || fail "The folder modules/app still exists."
expect_ref compute instance_profile_name module.iam
[ "$(state_json | jq -r '.values.outputs.asg_name.value // empty')" = orders-app ] || fail "The root output asg_name should be orders-app."
expect_original_resources
pass "modules/app is split into module.iam and module.compute."
