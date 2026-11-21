source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
expect_sg_module
expect_sg orders module.app_sg
expect_ref compute security_group_ids module.app_sg
expect_original_resources
pass "The security group is managed by the pinned platform module and kept its ID."
