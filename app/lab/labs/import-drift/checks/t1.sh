source "$LIB"
require_init
want=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=legacy-vpc --query 'Vpcs[0].VpcId' --output text)
got=$(state_attr aws_vpc.legacy id)
[ "$got" = "$want" ] || fail "aws_vpc.legacy should be in state with id $want (found: ${got:-nothing})."
expect_no_changes aws_vpc.legacy
pass "legacy VPC $want is managed and unchanged."
