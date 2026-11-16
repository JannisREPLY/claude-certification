source "$LIB"
require_init
vpc=$(state_attr aws_vpc.main id)
subnet=$(state_attr aws_subnet.app id)
[ "$vpc" = "$(cat "$LAB_STATE/vpc")" ] || fail "The VPC was replaced (ID changed)."
[ -n "$subnet" ] || fail "aws_subnet.app is missing from state."
[ "$subnet" != "$(cat "$LAB_STATE/subnet")" ] || fail "The subnet still has its original ID; it was not recreated."
pass "only the subnet was recreated."
