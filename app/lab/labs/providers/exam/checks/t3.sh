source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
expect_random_upgraded
pass "random is locked to 3.6.3 and random_integer.build kept its value."
