source "$LIB"
require_init
want=$(cat "$LAB_STATE/vpc")
got=$(state_json | jq -r '[.values.root_module.resources[]? | select(.mode == "data" and .type == "aws_vpc") | .values.id] | first // empty')
[ "$got" = "$want" ] || fail "No aws_vpc data source in state that found $want. Did you apply?"
grep -q "$want" *.tf && fail "The VPC ID $want is hardcoded in the configuration."
pass "shared VPC is looked up with a data source."
