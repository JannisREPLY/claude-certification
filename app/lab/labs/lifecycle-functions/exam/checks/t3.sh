source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
IFS='|' read -r keys rules <<< "$(rules_for "8080 9100" "10.0.0.0/8 192.168.0.0/16")"
check_rules "$keys" "$rules"
check_sg
pass "The worker security group is attached, has one rule per port and CIDR, and is replaced create-before-destroy."
