source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
check_asg
check_latest_version
check_depends_on
pass "The group keeps its capacity, follows the latest launch template version and depends on the policy attachment."
