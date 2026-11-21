source "$LIB"
require_init
ensure_plan
bad_plan() {
  local out
  out=$(terraform plan -lock=false -input=false -no-color -refresh=false "$@" 2>&1) && fail "terraform plan $* should fail."
  grep -q 'Invalid value for variable' <<< "$out" || fail "terraform plan $* should fail with a variable validation error:"$'\n'"$(tail -n 8 <<< "$out")"
}
bad_plan -var environment=qa
bad_plan -var admin_cidr=10.20.0.300/16
bad_plan -var admin_cidr=office
tf_has 'can\(\s*cidrhost\(' || fail "admin_cidr must be validated with can(cidrhost(...))."
for e in dev staging; do
  out=$(terraform plan -lock=false -input=false -no-color -refresh=false -var environment=$e 2>&1) || fail "terraform plan -var environment=$e should not fail:"$'\n'"$(tail -n 8 <<< "$out")"
done
env=$(aws ec2 describe-security-groups --filters Name=group-name,Values=nw-fw-app --query "SecurityGroups[0].Tags[?Key=='Environment'].Value | [0]" --output text)
[ "$env" = prod ] || fail "The security group nw-fw-app should carry the tag Environment = prod (found: $env)."
pass "environment and admin_cidr are validated, and nw-fw-app is tagged Environment = prod."
