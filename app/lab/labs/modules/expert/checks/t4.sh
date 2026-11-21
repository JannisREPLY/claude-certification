source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
expect_nothing_destroyed
expect_original_resources
expect_no_old_module
has_address 'module.compute["billing"].aws_autoscaling_group.this' || fail "Finish the refactoring first."
expect_ref compute instance_profile_name module.iam
expect_ref compute security_group_ids module.app_sg
expect_ref compute subnet_id data.aws_subnet
expect_ref app_sg vpc_id data.aws_vpc
expect_clean_plan
pass "Nothing was recreated in either application and the plan is clean."
