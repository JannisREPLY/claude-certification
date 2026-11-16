source "$LIB"
require_init
out=$(terraform plan -var environment=qa -lock=false -input=false -refresh=false -no-color 2>&1) && fail "terraform plan -var environment=qa succeeds."
grep -q "Invalid value for variable" <<< "$out" || fail "plan with environment = qa fails, but not because of variable validation:"$'\n'"$(tail -n 8 <<< "$out")"
for v in dev stage prod; do
  grep -q "$v" <<< "$out" || fail "The error message doesn't list the allowed value $v."
done
out=$(terraform plan -var environment=stage -lock=false -input=false -refresh=false -no-color 2>&1) || ! grep -q "Invalid value for variable" <<< "$out" || fail "environment = stage is rejected."
pass "environment is validated."
