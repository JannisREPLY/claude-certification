source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
check_user_data
pass "The fixed template renders one yum install line per package."
