source "$LIB"
require_init
for w in a b c; do
  want=$(cat "$LAB_STATE/worker-$w")
  [ "$(state_attr "aws_instance.worker[\"$w\"]" id)" = "$want" ] || fail "aws_instance.worker[\"$w\"] should be in state with the ID $want."
  expect_no_changes "aws_instance.worker[\"$w\"]"
done
[ "$(state_json | jq '[.values.root_module.resources[] | select(.address | startswith("aws_instance.worker[")) | .index | strings] | length')" = 3 ] || fail "aws_instance.worker must use for_each."
pass "The workers are managed with for_each and keep their IDs."
