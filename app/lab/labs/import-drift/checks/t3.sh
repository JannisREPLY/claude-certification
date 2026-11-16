source "$LIB"
require_init
id=$(state_attr aws_vpc.app id)
[ -n "$id" ] || fail "aws_vpc.app is missing from state."
env=$(aws ec2 describe-vpcs --vpc-ids "$id" --query "Vpcs[0].Tags[?Key=='Environment'].Value | [0]" --output text)
[ "$env" = "dev" ] || fail "The app VPC still has Environment = $env in AWS."
expect_no_changes aws_vpc.app
pass "app VPC is back to Environment = dev."
