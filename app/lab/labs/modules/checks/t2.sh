source "$LIB"
require_init
read -r vpc s0 s1 sg < <(xargs < "$LAB_STATE/ids")
a=$(state_attr 'module.network.aws_subnet.this["10.0.1.0/24"]' id)
b=$(state_attr 'module.network.aws_subnet.this["10.0.2.0/24"]' id)
[ -n "$a" ] && [ -n "$b" ] || fail "Expected module.network.aws_subnet.this[\"10.0.1.0/24\"] and [\"10.0.2.0/24\"] in state."
[ "$a $b" = "$s0 $s1" ] || fail "The subnets were recreated: IDs changed."
pass "subnets use for_each keyed by CIDR and kept their IDs."
