source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
expect_sg_module
for app in orders billing; do expect_sg "$app" "module.app_sg[\"$app\"]"; done
expect_ref compute security_group_ids module.app_sg
expect_original_resources
pass "Both security groups are managed by the pinned platform module and kept their IDs."
