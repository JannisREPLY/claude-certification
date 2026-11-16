source "$LIB"
require_init
read -r vpc s0 s1 sg < <(xargs < "$LAB_STATE/ids")
[ "$(state_attr module.network.aws_vpc.this id)" = "$vpc" ] || fail "module.network.aws_vpc.this is not the original VPC $vpc."
ids=$(state_json | jq -r '[.values.root_module.child_modules[]? | select(.address == "module.network") | .resources[] | select(.type == "aws_subnet") | .values.id] | sort | join(" ")')
[ "$ids" = "$(printf '%s\n' "$s0" "$s1" | sort | xargs)" ] || fail "module.network doesn't hold the two original subnets ($s0, $s1)."
[ -z "$(state_attr aws_vpc.main id)$(state_attr 'aws_subnet.public[0]' id)" ] || fail "The root module still has the old VPC or subnets in state."
for o in vpc_id subnet_ids; do grep -qE "output\s+\"$o\"" modules/network/*.tf || fail "modules/network has no output $o."; done
for v in cidr_block subnet_cidrs; do grep -qE "variable\s+\"$v\"" modules/network/*.tf || fail "modules/network has no variable $v."; done
pass "VPC and subnets live in module.network with their original IDs."
