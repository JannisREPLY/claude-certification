source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
expect_nothing_destroyed
expect_original_resources
expect_no_old_module
has_address module.compute.aws_autoscaling_group.this || fail "Finish the refactoring first."
expect_clean_plan
pass "Nothing was recreated and the plan is clean."
