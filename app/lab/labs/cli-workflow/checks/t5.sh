source "$LIB"
require_init
out=$(terraform plan -destroy -var-file=prod.tfvars -lock=false -input=false -no-color 2>&1) && fail "terraform plan -destroy still succeeds."
grep -q "Instance cannot be destroyed" <<< "$out" || fail "terraform plan -destroy fails, but not because of the VPC protection:"$'\n'"$(tail -n 8 <<< "$out")"
pass "destroying the VPC is blocked."
