source "$LIB"
require_init
n=$(aws ec2 describe-security-groups --filters Name=group-name,Values=debug --query 'length(SecurityGroups)' --output text)
[ "$n" = "0" ] || fail "The debug security group still exists in AWS."
[ "$(state_attr aws_vpc.main id)" = "$(cat "$LAB_STATE/vpc")" ] || fail "The VPC was replaced (ID changed)."
grep -q 'aws_security_group' *.tf && fail "The configuration still contains the security group."
pass "debug security group is gone, the rest is untouched."
