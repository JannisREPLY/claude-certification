source "$LIB"
require_init
[ -f tfplan ] || fail "No plan file tfplan in the lab folder."
env=$(terraform show -json tfplan 2>/dev/null | jq -r '.variables.environment.value // empty') || fail "tfplan is not a valid plan file."
[ "$env" = "prod" ] || fail "tfplan was created with environment = ${env:-?}, not prod."
pass "tfplan is a production plan."
