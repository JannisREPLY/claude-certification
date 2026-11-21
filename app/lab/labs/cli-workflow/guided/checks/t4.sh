source "$LAB_DIR/helpers.sh"
check_debug_gone
prod_plan
pass "The debug resources are gone and the plan with prod.tfvars is clean."
