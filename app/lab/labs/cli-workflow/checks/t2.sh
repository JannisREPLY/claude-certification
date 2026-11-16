source "$LIB"
require_init
env=$(aws ec2 describe-vpcs --vpc-ids "$(cat "$LAB_STATE/vpc")" --query "Vpcs[0].Tags[?Key=='Environment'].Value | [0]" --output text 2>/dev/null) || fail "The original VPC is gone."
[ "$env" = "prod" ] || fail "The VPC has Environment = $env in AWS."
pass "production values are applied."
