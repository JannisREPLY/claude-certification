source "$LIB"
require_init
id=$(cat "$LAB_STATE/tracker")
[ "$(state_attr aws_security_group.tracker id)" = "$id" ] || fail "aws_security_group.tracker is not the original nw-bf-tracker-sg ($id)."
sg=$(aws ec2 describe-security-groups --group-ids "$id" --query 'SecurityGroups[0]' --output json 2> /dev/null) || fail "nw-bf-tracker-sg ($id) no longer exists."
[ "$(jq '[.IpPermissions[] | select(.FromPort == 22)] | length' <<< "$sg")" = 0 ] || fail "The unapproved SSH (22) ingress rule is still on nw-bf-tracker-sg."
[ "$(jq '[.IpPermissions[] | select(.FromPort == 8443)] | length' <<< "$sg")" = 1 ] || fail "The 8443 ingress rule of nw-bf-tracker-sg is gone."
[ "$(jq -r '.Tags[]? | select(.Key == "Owner") | .Value' <<< "$sg")" = dispatch-oncall ] || fail "The approved tag Owner = dispatch-oncall is missing on nw-bf-tracker-sg."
[ "$(state_attr aws_security_group.tracker tags | jq -r .Owner)" = dispatch-oncall ] || fail "Owner = dispatch-oncall is not in the configuration of aws_security_group.tracker."
expect_no_changes aws_security_group.tracker
pass "nw-bf-tracker-sg has no SSH rule and keeps Owner = dispatch-oncall."
