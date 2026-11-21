source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
IFS='|' read -r keys rules <<< "$(rules_for "8080 9100" "10.0.0.0/8 192.168.0.0/16")"
check_rules "$keys" "$rules"
expect_clean_plan
pass "One ingress rule per port and CIDR, and the plan is clean."
