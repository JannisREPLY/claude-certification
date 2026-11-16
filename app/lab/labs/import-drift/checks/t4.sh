source "$LIB"
require_init
id=$(state_attr aws_subnet.app id)
[ -n "$id" ] || fail "aws_subnet.app is missing from state."
owner=$(aws ec2 describe-subnets --subnet-ids "$id" --query "Subnets[0].Tags[?Key=='Owner'].Value | [0]" --output text)
[ "$owner" = "platform" ] || fail "The Owner = platform tag is gone from the subnet in AWS."
expect_no_changes aws_subnet.app
pass "subnet keeps Owner = platform and matches the configuration."
