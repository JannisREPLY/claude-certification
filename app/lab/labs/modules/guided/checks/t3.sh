source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
expect_addresses module.compute.aws_launch_template.this module.compute.aws_autoscaling_group.this
expect_no_old_module
[ ! -e modules/app ] || fail "The folder modules/app still exists."
expect_ref compute instance_profile_name module.iam
expect_ref compute security_group_ids module.app_sg
[ "$(state_json | jq -r '.values.outputs.asg_name.value // empty')" = orders-app ] || fail "The root output asg_name should be orders-app."
expect_original_resources
pass "The launch template and the Auto Scaling group live in module.compute, wired from module outputs."
