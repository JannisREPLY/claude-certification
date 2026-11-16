source "$LIB"
require_init
for r in us-east-1 us-west-2; do
  missing=$(aws ec2 describe-vpcs --region $r --query "Vpcs[?!(Tags[?Key=='ManagedBy' && Value=='terraform'])] | [?!IsDefault].VpcId" --output text)
  [ -z "$missing" ] || fail "VPCs in $r without ManagedBy = terraform: $missing"
done
[ "$(grep -c 'ManagedBy' *.tf | awk -F: '{s+=$2} END {print s}')" -le 2 ] || fail "ManagedBy is repeated on resources; set it once per provider configuration."
ensure_plan
changes=$(plan_json | jq -r '[.resource_changes[]? | select(.change.actions != ["no-op"]) | "\(.address): \(.change.actions | join(","))"] | join("\n")')
[ -z "$changes" ] || fail "terraform plan still has changes:"$'\n'"$changes"
[ "$(state_attr random_pet.suffix id)" = "$(cat "$LAB_STATE/pet")" ] || fail "random_pet.suffix was recreated."
pass "all VPCs are tagged and the plan is clean."
