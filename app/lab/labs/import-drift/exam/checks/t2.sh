source "$LIB"
require_init
want=$(cat "$LAB_STATE/sg")
[ "$(state_attr aws_security_group.legacy_api id)" = "$want" ] || fail "aws_security_group.legacy_api should be in state with the ID $want."
rules=$(aws ec2 describe-security-groups --group-ids "$want" --query 'SecurityGroups[0].IpPermissions[?FromPort==`443`] | length(@)' --output text)
[ "$rules" = 1 ] || fail "The HTTPS (443) ingress rule of legacy-api-sg is gone."
config_json | jq -e '.root_module.resources[] | select(.address=="aws_instance.legacy_api") | .expressions.vpc_security_group_ids.references // [] | index("aws_security_group.legacy_api.id")' > /dev/null \
  || fail "vpc_security_group_ids of aws_instance.legacy_api must reference aws_security_group.legacy_api.id."
expect_no_changes aws_security_group.legacy_api
pass "legacy-api-sg is managed, unchanged and referenced by the instance."
