source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
inputs_unchanged
check_data_sources
check_instance_set "batch web-1 web-2"
[ -z "$(aws ec2 describe-instances --filters Name=tag:Name,Values=old Name=instance-state-name,Values=pending,running --query 'Reservations[].Instances[].InstanceId' --output text)" ] || fail "The disabled instance old is running."
check_instance web-1 t3.micro 0 '{"Name":"web-1","Role":"web"}'
check_instance web-2 t3.micro 7 '{"Name":"web-2","Role":"web"}'
check_instance batch t3.small 0 '{"Name":"batch","Role":"worker","Schedule":"nightly"}'
pass "Only enabled instances exist, subnet indexes wrap around, tags are merged."
