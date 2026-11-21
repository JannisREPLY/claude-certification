source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
inputs_unchanged
check_data_sources
check_instance_set "batch web-1 web-2"
check_instance web-1 t3.micro 0 '{"Name":"web-1"}'
check_instance web-2 t3.micro 1 '{"Name":"web-2"}'
check_instance batch t3.small 0 '{"Name":"batch","Schedule":"nightly"}'
pass "The three instances run with the expected AMI, type, subnet and tags."
