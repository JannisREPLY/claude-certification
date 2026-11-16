source "$LIB"
require_init
ensure_plan
changes=$(plan_json | jq -r '[.resource_changes[]? | select(.change.actions != ["no-op"]) | "\(.address): \(.change.actions | join(","))"] | join("\n")')
[ -z "$changes" ] || fail "terraform plan still has changes:"$'\n'"$changes"
pass "terraform plan reports no changes."
