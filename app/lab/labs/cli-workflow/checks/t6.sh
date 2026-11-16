source "$LIB"
require_init
terraform plan -var-file=prod.tfvars -detailed-exitcode -lock=false -input=false -no-color > "$CHECK_TMP/p.log" 2>&1
case $? in
  0) pass "no changes with prod.tfvars." ;;
  2) fail "terraform plan -var-file=prod.tfvars still has changes:"$'\n'"$(grep -E '^  # ' "$CHECK_TMP/p.log")" ;;
  *) fail "terraform plan fails:"$'\n'"$(tail -n 15 "$CHECK_TMP/p.log")" ;;
esac
