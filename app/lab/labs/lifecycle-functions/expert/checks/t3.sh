source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
IFS='|' read -r keys rules <<< "$(rules_for "8080 9100 9200" "10.0.0.0/8 172.16.0.0/12 192.168.0.0/16" "9200-192.168.0.0/16 9200-172.16.0.0/12")"
check_rules "$keys" "$rules"
check_sg "Orders workers"
plan_with desc -var 'sg_description=Orders workers v2'
actions_in desc random_integer.suffix | jq -e 'index("delete") and index("create")' > /dev/null || fail "Changing sg_description does not generate a new suffix (random_integer.suffix: $(actions_in desc random_integer.suffix))."
[ "$(actions_in desc aws_security_group.worker)" = '["create","delete"]' ] || fail "Changing sg_description plans aws_security_group.worker as $(actions_in desc aws_security_group.worker), expected create before destroy."
pass "The worker group gets a new name on replacement, is replaced create-before-destroy and has the expected rules."
