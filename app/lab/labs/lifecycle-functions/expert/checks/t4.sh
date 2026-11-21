source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
check_canary
want=$(addresses | sed -n 's/^aws_vpc_security_group_ingress_rule\.worker\["\(.*\)"\]$/\1/p' | LC_ALL=C sort | jq -Rsc 'split("\n") | map(select(length > 0))')
[ "$want" != "[]" ] || fail "No aws_vpc_security_group_ingress_rule.worker in state."
[ "$(terraform output -json -no-color | jq -c '.worker_rule_keys.value')" = "$want" ] || fail "worker_rule_keys should be $want."
expect_clean_plan
pass "The canary is optional and follows launch template versions, the outputs are correct and the plan is clean."
