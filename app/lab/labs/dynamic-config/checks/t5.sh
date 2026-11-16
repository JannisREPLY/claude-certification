source "$LIB"
require_init
outputs=$(terraform output -json -no-color)
for key in web app db; do
  want=$(state_attr "aws_subnet.this[\"$key\"]" id)
  got=$(jq -r --arg k "$key" '.subnet_ids.value[$k] // empty' <<< "$outputs")
  [ -n "$want" ] && [ "$got" = "$want" ] || fail "Output subnet_ids[\"$key\"] is '${got}', expected the ID of aws_subnet.this[\"$key\"]. Did you apply?"
done
public=$(jq -c '.public_subnet_ids.value // empty' <<< "$outputs")
[ "$public" = "[\"$(state_attr 'aws_subnet.this["web"]' id)\"]" ] || fail "Output public_subnet_ids is ${public:-missing}, expected a list with only the web subnet ID."
pass "outputs are correct."
