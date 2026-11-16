source "$LIB"
require_init
want=$(aws ec2 describe-security-groups --filters Name=group-name,Values=legacy-web --query 'SecurityGroups[0].GroupId' --output text)
got=$(state_attr aws_security_group.legacy_web id)
[ "$got" = "$want" ] || fail "aws_security_group.legacy_web should be in state with id $want (found: ${got:-nothing})."
rules=$(aws ec2 describe-security-groups --group-ids "$want" --query 'SecurityGroups[0].IpPermissions[?FromPort==`443`] | length(@)' --output text)
[ "$rules" = "1" ] || fail "The HTTPS (443) ingress rule of legacy-web is gone."
expect_no_changes aws_security_group.legacy_web
pass "security group $want is managed and unchanged."
