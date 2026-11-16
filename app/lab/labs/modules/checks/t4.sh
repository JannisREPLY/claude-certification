source "$LIB"
require_init
[ -n "$(state_attr module.network.aws_vpc.this id)" ] && [ -n "$(state_attr module.web_sg.aws_security_group.this id)" ] || fail "Finish the refactoring (t1–t3) first."
ensure_plan
changes=$(plan_json | jq -r '[.resource_changes[]? | select(.change.actions != ["no-op"]) | "\(.address): \(.change.actions | join(","))"] | join("\n")')
[ -z "$changes" ] || fail "terraform plan still has changes:"$'\n'"$changes"
pass "terraform plan reports no changes."
