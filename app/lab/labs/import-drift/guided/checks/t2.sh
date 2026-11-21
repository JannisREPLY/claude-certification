source "$LIB"
require_init
want=$(cat "$LAB_STATE/instance")
[ "$(state_attr aws_instance.legacy_api id)" = "$want" ] || fail "aws_instance.legacy_api should be in state with the ID $want."
expect_no_changes aws_instance.legacy_api
pass "Instance $want is managed and unchanged."
