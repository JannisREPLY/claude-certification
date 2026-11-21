source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
expect_west_bucket module.reports.aws_s3_bucket.replica
expect_module_aliases
ensure_plan
want="web-west-$(cat "$LAB_STATE/build")"
id=$(state_attr aws_security_group.web_west id)
[ -n "$id" ] || fail "aws_security_group.web_west is not in state."
name=$(aws ec2 describe-security-groups --region us-west-2 --group-ids "$id" --query 'SecurityGroups[0].GroupName' --output text 2> /dev/null) || fail "aws_security_group.web_west ($id) is not in us-west-2."
[ "$name" = "$want" ] || fail "aws_security_group.web_west is named $name, not $want."
config_json | jq -e '.root_module.resources[] | select(.address == "aws_security_group.web_west") | .expressions.vpc_id.references // [] | index("data.aws_vpc.default_west.id")' > /dev/null \
  || fail "aws_security_group.web_west must use data.aws_vpc.default_west.id."
[ "$(config_json | jq -r '.root_module.resources[] | select(.address == "data.aws_vpc.default_west") | .provider_config_key')" = aws.west ] \
  || fail "data.aws_vpc.default_west must use the provider aws.west."
pass "The replica bucket and $want exist in us-west-2."
