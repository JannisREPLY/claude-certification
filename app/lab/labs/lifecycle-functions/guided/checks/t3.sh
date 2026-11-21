source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
check_sg
pass "The security group has a random suffix, is attached and is replaced create-before-destroy."
