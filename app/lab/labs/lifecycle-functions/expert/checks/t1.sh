source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
check_asg
[ "$(asg | jq -r .MaxSize)" = 8 ] || fail "MaxSize of orders-workers is $(asg | jq -r .MaxSize), expected 8."
check_latest_version
check_depends_on
pass "The group keeps its capacity, allows 8 instances, follows the latest launch template version and depends on the policy attachment."
