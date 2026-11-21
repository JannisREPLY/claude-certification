source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
check_asg
pass "orders-workers keeps 4 instances and Terraform no longer changes desired_capacity."
